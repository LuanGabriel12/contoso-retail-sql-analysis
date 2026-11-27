/*
================================================================================
ARQUIVO: sql/validation/03_validacao_calculos_financeiros.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Validação de Dados (Sanidade Financeira e Regra de Margem Ponderada)
================================================================================

1. PERGUNTA EMPRESARIAL
   Os valores de vendas, custos e quantidades são válidos (positivos, sem risco
   de divisão por zero não tratada), qual a relação entre SalesAmount, descontos
   e devoluções, e qual o erro causado caso a margem comercial seja calculada
   como média simples em vez de lucro total dividido por vendas totais?

2. TABELAS UTILIZADAS
   - dbo.FactSales

3. LÓGICA DA CONSULTA
   - Bloco 1: Audita ocorrências de valores zerados ou negativos em SalesAmount,
     TotalCost e SalesQuantity, além de registros com prejuízo bruto
     (SalesAmount < TotalCost).
   - Bloco 2: Verifica se SalesAmount já está líquido de DiscountAmount
     comparando SalesAmount com (UnitPrice * SalesQuantity) - DiscountAmount
     dentro de tolerância de 0,01. Também compara TotalCost com
     UnitCost * SalesQuantity e com UnitCost * (SalesQuantity - ReturnQuantity).
   - Bloco 3: Demonstra numericamente a diferença entre:
     (a) Margem Comercial Correta (ponderada): (SUM(SalesAmount) - SUM(TotalCost)) / NULLIF(SUM(SalesAmount), 0)
     (b) Média simples das margens por linha (INCORRETA)
     (c) Média simples das margens por produto (INCORRETA, usando CTE).

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Sanidade de sinais: 0 linhas com SalesAmount <= 0, TotalCost <= 0,
     SalesQuantity <= 0 ou prejuízo bruto (SalesAmount < TotalCost).
   - Descontos e devoluções: 1.793.112 linhas com DiscountAmount > 0 e
     480.943 linhas com ReturnQuantity > 0.
   - Composição das métricas: 0 divergências entre SalesAmount e
     (UnitPrice * SalesQuantity) - DiscountAmount (SalesAmount já é líquido
     de desconto). TotalCost diverge de UnitCost * SalesQuantity em 319.080
     linhas e de UnitCost * (SalesQuantity - ReturnQuantity) em 166.830 linhas,
     confirmando que a coluna oficial TotalCost deve ser usada diretamente.
   - Margem Comercial Ponderada vs. Média Simples:
     * Margem Ponderada Correta: 56,7823%
     * Média Simples por Linha (INCORRETA): 53,3095% (erro de -3,4728 p.p.)
     * Média Simples por Produto (INCORRETA): 54,2414% (erro de -2,5409 p.p.)

5. INTERPRETAÇÃO EMPRESARIAL
   Valida a integridade matemática das fórmulas financeiras do projeto e prova,
   com dados reais, por que a margem comercial deve sempre ser calculada como
   razão de agregações (DIVIDE([Lucro Comercial], [Vendas Totais]) no Power BI).

6. POSSÍVEIS LIMITAÇÕES
   - SalesAmount já desconta DiscountAmount, mas ReturnAmount é registrado em
     coluna separada. Portanto, Lucro Comercial (SalesAmount - TotalCost)
     representa margem bruta comercial sobre vendas faturadas e não contempla
     estornos financeiros de devolução, impostos ou despesas operacionais.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Auditoria de valores zerados, negativos e linhas com prejuízo bruto
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS TotalLinhas,
    SUM(CASE WHEN SalesAmount <= 0 THEN 1 ELSE 0 END) AS VendasMenorIgualZero,
    SUM(CASE WHEN TotalCost <= 0 THEN 1 ELSE 0 END) AS CustoMenorIgualZero,
    SUM(CASE WHEN SalesQuantity <= 0 THEN 1 ELSE 0 END) AS QuantidadeMenorIgualZero,
    SUM(CASE WHEN SalesAmount < TotalCost THEN 1 ELSE 0 END) AS LinhasComPrejuizoBruto,
    SUM(CASE WHEN ReturnQuantity > 0 THEN 1 ELSE 0 END) AS LinhasComDevolucao,
    SUM(CASE WHEN DiscountAmount > 0 THEN 1 ELSE 0 END) AS LinhasComDesconto
FROM dbo.FactSales;

-- -----------------------------------------------------------------------------
-- 2. Auditoria da composição de SalesAmount e TotalCost
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS TotalLinhas,
    SUM(CASE
            WHEN (SalesAmount - ((UnitPrice * SalesQuantity) - DiscountAmount)) > 0.01
              OR (SalesAmount - ((UnitPrice * SalesQuantity) - DiscountAmount)) < -0.01
            THEN 1 ELSE 0
        END) AS DivergenciaSalesAmountFormula,
    SUM(CASE
            WHEN (TotalCost - (UnitCost * SalesQuantity)) > 0.01
              OR (TotalCost - (UnitCost * SalesQuantity)) < -0.01
            THEN 1 ELSE 0
        END) AS DivergenciaTotalCostVsBruto,
    SUM(CASE
            WHEN (TotalCost - (UnitCost * (SalesQuantity - ReturnQuantity))) > 0.01
              OR (TotalCost - (UnitCost * (SalesQuantity - ReturnQuantity))) < -0.01
            THEN 1 ELSE 0
        END) AS DivergenciaTotalCostVsLiquidoDevolucao
FROM dbo.FactSales;

-- -----------------------------------------------------------------------------
-- 3. Comparação: Margem Ponderada (CORRETA) vs. Médias Simples (INCORRETAS)
-- -----------------------------------------------------------------------------
WITH MargemPorProduto AS (
    SELECT
        ProductKey,
        CAST((SUM(SalesAmount) - SUM(TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(SalesAmount), 0) AS MargemProduto
    FROM dbo.FactSales
    GROUP BY ProductKey
),
ResumoGeral AS (
    SELECT
        CAST((SUM(SalesAmount) - SUM(TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(SalesAmount), 0) AS MargemPonderadaCorreta,
        AVG(
            CAST((SalesAmount - TotalCost) AS DECIMAL(18, 6))
                / NULLIF(SalesAmount, 0)
        ) AS MediaSimplesPorLinhaIncorreta
    FROM dbo.FactSales
)
SELECT
    CAST(R.MargemPonderadaCorreta * 100 AS DECIMAL(10, 4)) AS MargemPonderadaCorretaPct,
    CAST(R.MediaSimplesPorLinhaIncorreta * 100 AS DECIMAL(10, 4)) AS MediaSimplesLinhasIncorretaPct,
    CAST((SELECT AVG(MargemProduto) FROM MargemPorProduto) * 100 AS DECIMAL(10, 4)) AS MediaSimplesProdutosIncorretaPct,
    CAST((R.MargemPonderadaCorreta - R.MediaSimplesPorLinhaIncorreta) * 100 AS DECIMAL(10, 4)) AS ErroPontosPercentuaisLinha
FROM ResumoGeral AS R;

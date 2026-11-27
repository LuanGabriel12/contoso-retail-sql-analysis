/*
================================================================================
ARQUIVO: sql/commercial_analysis/01_evolucao_anual_e_mensal.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Análise Comercial (Evolução Temporal: Anual, Mensal e Sazonalidade)
================================================================================

1. PERGUNTA EMPRESARIAL
   Como evoluíram faturamento, lucro comercial, margem e volume vendido ano a
   ano (2007 a 2009) e mês a mês ao longo dos 36 meses, e quais meses do
   calendário concentram maior sazonalidade de receita?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimDate

3. LÓGICA DA CONSULTA
   - Consulta 1 (Evolução anual com variação YoY): Usa uma CTE (ResumoAnual) e
     auto-relacionamento via LEFT JOIN (Atual.Ano = Anterior.Ano + 1) para
     calcular variação percentual ano contra ano em vendas, lucro e unidades
     sem exigir funções de janela avançadas fora do escopo dominado.
   - Consulta 2 (Série mensal completa 2007-2009): Agrupa por CalendarYear,
     MONTH(D.Datekey) e CalendarMonthLabel, ordenado cronologicamente.
   - Consulta 3 (Sazonalidade média por mês do ano): Consolida os 3 anos por
     mês do calendário (1 a 12) para evidenciar picos e vales sazonais.

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Evolução Anual (YoY):
     * 2007: USD 4.561.940.955,02 | 16.984.310 un. | USD 268,60/un. | Margem 56,88%
     * 2008: USD 4.111.233.534,68 (-9,88% YoY) | 16.511.811 un. (-2,78% YoY) | USD 248,99/un. | Margem 56,87%
     * 2009: USD 3.740.483.119,18 (-9,02% YoY) | 19.824.333 un. (+20,06% YoY) | USD 188,68/un. | Margem 56,57%
   - Série Mensal (36 meses): pico mensal em nov/2007 (USD 453,75 mi) e menor
     mês em fev/2009 (USD 266,00 mi); margem mensal entre 55,05% (nov-dez/2009)
     e 57,83% (out/2009).
   - Sazonalidade consolidada (média 2007-2009): novembro lidera (USD 386,33 mi/mês),
     seguido de dezembro (USD 385,13 mi/mês) e maio (USD 372,03 mi/mês); janeiro
     é o mês mais fraco (USD 273,02 mi/mês).

5. INTERPRETAÇÃO EMPRESARIAL
   Permite identificar simultaneamente a trajetória de receita, a preservação
   de margem e eventuais mudanças no mix de preços (volume x receita unitária),
   além de apoiar planejamento de estoque e campanhas sazonais.

6. POSSÍVEIS LIMITAÇÕES
   - A base contém apenas 3 anos completos (2007-2009); 2007 não possui ano
     anterior para cálculo de variação YoY (retorna NULL de forma esperada).
   - A sazonalidade reflete dados sintéticos da base demonstrativa Contoso.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Evolução Anual com Variação YoY (CTE + LEFT JOIN)
-- -----------------------------------------------------------------------------
WITH ResumoAnual AS (
    SELECT
        D.CalendarYear AS Ano,
        SUM(F.SalesAmount) AS VendasTotais,
        SUM(F.TotalCost) AS CustoTotal,
        SUM(F.SalesQuantity) AS UnidadesVendidas,
        SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
        CAST(
            CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
                / NULLIF(SUM(F.SalesAmount), 0) * 100
            AS DECIMAL(10, 2)
        ) AS MargemComercialPct,
        CAST(
            CAST(SUM(F.SalesAmount) AS DECIMAL(18, 6))
                / NULLIF(SUM(F.SalesQuantity), 0)
            AS DECIMAL(18, 2)
        ) AS ReceitaPorUnidade
    FROM dbo.FactSales AS F
    INNER JOIN dbo.DimDate AS D
        ON F.DateKey = D.Datekey
    GROUP BY D.CalendarYear
)
SELECT
    Atual.Ano,
    Atual.VendasTotais,
    Atual.CustoTotal,
    Atual.LucroComercial,
    Atual.MargemComercialPct,
    Atual.UnidadesVendidas,
    Atual.ReceitaPorUnidade,
    CAST(
        CAST((Atual.VendasTotais - Anterior.VendasTotais) AS DECIMAL(18, 6))
            / NULLIF(Anterior.VendasTotais, 0) * 100
        AS DECIMAL(10, 2)
    ) AS VariacaoVendasYoYPct,
    CAST(
        CAST((Atual.UnidadesVendidas - Anterior.UnidadesVendidas) AS DECIMAL(18, 6))
            / NULLIF(Anterior.UnidadesVendidas, 0) * 100
        AS DECIMAL(10, 2)
    ) AS VariacaoUnidadesYoYPct
FROM ResumoAnual AS Atual
LEFT JOIN ResumoAnual AS Anterior
    ON Atual.Ano = Anterior.Ano + 1
ORDER BY Atual.Ano;

-- -----------------------------------------------------------------------------
-- 2. Série Mensal Completa (36 meses: jan/2007 a dez/2009)
-- -----------------------------------------------------------------------------
SELECT
    D.CalendarYear AS Ano,
    MONTH(D.Datekey) AS NumeroMes,
    D.CalendarMonthLabel AS NomeMes,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0) * 100
        AS DECIMAL(10, 2)
    ) AS MargemComercialPct
FROM dbo.FactSales AS F
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
GROUP BY
    D.CalendarYear,
    MONTH(D.Datekey),
    D.CalendarMonthLabel
ORDER BY
    D.CalendarYear,
    MONTH(D.Datekey);

-- -----------------------------------------------------------------------------
-- 3. Sazonalidade Consolidada por Mês do Calendário (2007-2009)
-- -----------------------------------------------------------------------------
WITH MensalPorAno AS (
    SELECT
        D.CalendarYear AS Ano,
        MONTH(D.Datekey) AS NumeroMes,
        D.CalendarMonthLabel AS NomeMes,
        SUM(F.SalesAmount) AS VendasMes,
        SUM(F.SalesQuantity) AS UnidadesMes
    FROM dbo.FactSales AS F
    INNER JOIN dbo.DimDate AS D
        ON F.DateKey = D.Datekey
    GROUP BY
        D.CalendarYear,
        MONTH(D.Datekey),
        D.CalendarMonthLabel
)
SELECT
    NumeroMes,
    NomeMes,
    SUM(VendasMes) AS VendasAcumuladas3Anos,
    CAST(AVG(VendasMes) AS DECIMAL(18, 2)) AS MediaMensalVendas,
    SUM(UnidadesMes) AS UnidadesAcumuladas3Anos
FROM MensalPorAno
GROUP BY NumeroMes, NomeMes
ORDER BY NumeroMes;

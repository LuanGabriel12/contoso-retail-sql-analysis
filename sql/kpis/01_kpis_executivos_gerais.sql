/*
================================================================================
ARQUIVO: sql/kpis/01_kpis_executivos_gerais.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  KPIs Executivos (Visão Consolidada e Visão Anual)
================================================================================

1. PERGUNTA EMPRESARIAL
   Quais são os resultados consolidados da operação comercial da Contoso em
   faturamento, custo total, unidades vendidas, lucro comercial, margem
   comercial e indicadores unitários no período completo (2007-2009) e por ano?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimDate

3. LÓGICA DA CONSULTA
   - Bloco 1: Agrega os cinco KPIs principais diretamente na FactSales com
     proteção contra divisão por zero (NULLIF) e conversão explícita (CAST)
     para evitar truncamento da divisão do tipo MONEY no SQL Server.
   - Bloco 2: Agrupa os mesmos KPIs por DimDate.CalendarYear para comparação
     anual consistente com o modelo estrela do Power BI.

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Consolidado (2007-2009):
     * Vendas Totais:     USD 12.413.657.608,8876 (~USD 12,41 bilhões)
     * Custo Total:       USD 5.364.896.601,7800  (~USD 5,36 bilhões)
     * Unidades Vendidas: 53.320.454
     * Lucro Comercial:   USD 7.048.761.007,1076  (~USD 7,05 bilhões)
     * Margem Comercial:  56,78%
     * Receita / Unidade: USD 232,81 | Custo / Unid.: USD 100,62 | Lucro / Unid.: USD 132,20
   - Por Ano:
     * 2007: Vendas USD 4,56 bi | Lucro USD 2,60 bi | Margem 56,88% | 16.984.310 un. | USD 268,60/un.
     * 2008: Vendas USD 4,11 bi | Lucro USD 2,34 bi | Margem 56,87% | 16.511.811 un. | USD 248,99/un.
     * 2009: Vendas USD 3,74 bi | Lucro USD 2,12 bi | Margem 56,57% | 19.824.333 un. | USD 188,68/un.

5. INTERPRETAÇÃO EMPRESARIAL
   Fornece o painel numérico de referência executiva da empresa e serve como
   linha de base para avaliar a evolução comercial ao longo dos três anos.

6. POSSÍVEIS LIMITAÇÕES
   - Todos os registros da FactSales estão em USD (CurrencyKey = 1) no período
     de 2007 a 2009; não contempla vendas da tabela separada FactOnlineSales.
   - Lucro Comercial equivale a SalesAmount - TotalCost (margem bruta comercial).
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. KPIs Executivos Consolidados (2007-2009)
-- -----------------------------------------------------------------------------
SELECT
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
    ) AS ReceitaPorUnidade,
    CAST(
        CAST(SUM(F.TotalCost) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesQuantity), 0)
        AS DECIMAL(18, 2)
    ) AS CustoPorUnidade,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesQuantity), 0)
        AS DECIMAL(18, 2)
    ) AS LucroPorUnidade
FROM dbo.FactSales AS F;

-- -----------------------------------------------------------------------------
-- 2. KPIs Executivos por Ano (DimDate.CalendarYear)
-- -----------------------------------------------------------------------------
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
ORDER BY D.CalendarYear;

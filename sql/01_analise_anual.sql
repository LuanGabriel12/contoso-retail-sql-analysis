-- Análise 01 | ContosoRetailDW
-- Consolidar faturamento, unidades, custo e lucro bruto estimado por ano.

SELECT
    YEAR(DateKey) AS Ano,
    SUM(SalesAmount) AS Faturamento,
    SUM(SalesQuantity) AS UnidadesVendidas,
    SUM(TotalCost) AS CustoTotal,
    SUM(SalesAmount) - SUM(TotalCost) AS LucroBrutoEstimado
FROM dbo.FactSales
GROUP BY YEAR(DateKey)
ORDER BY Faturamento DESC;

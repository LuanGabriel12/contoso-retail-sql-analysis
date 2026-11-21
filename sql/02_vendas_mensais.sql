-- Análise 02 | ContosoRetailDW
-- Acompanhar a evolução mensal do faturamento e do volume vendido em 2008.

SELECT
    YEAR(DateKey) AS Ano,
    MONTH(DateKey) AS Mes,
    SUM(SalesAmount) AS Faturamento,
    SUM(SalesQuantity) AS UnidadesVendidas
FROM dbo.FactSales
WHERE YEAR(DateKey) = 2008
GROUP BY YEAR(DateKey), MONTH(DateKey)
ORDER BY MONTH(DateKey);

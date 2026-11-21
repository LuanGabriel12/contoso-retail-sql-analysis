-- Análise 03 | ContosoRetailDW
-- Identificar os dez produtos com maior faturamento na FactSales.

SELECT TOP (10)
    SUM(F.SalesAmount) AS Faturamento,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    P.ProductKey,
    P.ProductName AS NomeDoProduto,
    P.BrandName AS Marca
FROM dbo.FactSales AS F
INNER JOIN dbo.DimProduct AS P
    ON P.ProductKey = F.ProductKey
GROUP BY P.ProductKey, P.ProductName, P.BrandName
ORDER BY Faturamento DESC;

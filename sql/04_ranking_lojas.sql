-- Análise 04 | ContosoRetailDW
-- Identificar as cinco lojas com maior faturamento em 2008.

SELECT TOP (5)
    YEAR(F.DateKey) AS Ano,
    SUM(F.SalesAmount) AS Faturamento,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    S.StoreKey,
    S.StoreName AS NomeDaLoja,
    S.StoreType AS TipoDaLoja
FROM dbo.FactSales AS F
INNER JOIN dbo.DimStore AS S
    ON S.StoreKey = F.StoreKey
WHERE F.DateKey >= '20080101'
    AND F.DateKey < '20090101'
GROUP BY YEAR(F.DateKey), S.StoreName, S.StoreType, S.StoreKey
ORDER BY Faturamento DESC;

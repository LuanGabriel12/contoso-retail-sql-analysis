-- Análise 08 | ContosoRetailDW
-- Listar produtos sem registros correspondentes na FactSales.

SELECT
    P.ProductKey,
    P.ProductName AS NomeDoProduto,
    P.BrandName AS Marca,
    P.UnitPrice AS Preco
FROM dbo.DimProduct AS P
LEFT JOIN dbo.FactSales AS F
    ON P.ProductKey = F.ProductKey
WHERE F.ProductKey IS NULL
ORDER BY Preco DESC;

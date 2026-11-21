-- Análise 06 | ContosoRetailDW
-- Identificar até dez produtos com mais de 290 unidades devolvidas, em todo o período.

SELECT TOP (10)
    P.ProductKey,
    P.ProductName AS NomeDoProduto,
    SUM(F.ReturnQuantity) AS QuantidadeDevolvida,
    SUM(F.ReturnAmount) AS ValorDevolvido,
    SUM(F.SalesQuantity) AS UnidadesVendidas
FROM dbo.FactSales AS F
INNER JOIN dbo.DimProduct AS P
    ON P.ProductKey = F.ProductKey
GROUP BY P.ProductName, P.ProductKey
HAVING SUM(F.ReturnQuantity) > 290
ORDER BY QuantidadeDevolvida DESC;

-- Análise 07 | ContosoRetailDW
-- Comparar o sortimento por classe para preços unitários entre 100 e 500, inclusive.

SELECT
    ClassName AS ClasseDoProduto,
    COUNT(DISTINCT ProductKey) AS QuantidadeDeProdutos,
    COUNT(DISTINCT BrandName) AS QuantidadeDeMarcas,
    AVG(UnitPrice) AS PrecoMedio
FROM dbo.DimProduct
WHERE UnitPrice BETWEEN 100 AND 500
GROUP BY ClassName
ORDER BY QuantidadeDeProdutos DESC;

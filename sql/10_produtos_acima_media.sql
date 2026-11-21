-- Análise 10 | ContosoRetailDW
-- Comparar o faturamento de cada produto com a média dos totais por produto em 2008.
-- A subconsulta calcula a média após somar as vendas de cada produto.

SELECT
    ProductKey,
    SUM(SalesAmount) AS FaturamentoProduto
FROM dbo.FactSales
WHERE YEAR(DateKey) = 2008
GROUP BY ProductKey
HAVING SUM(SalesAmount) > (
    SELECT AVG(FaturamentoProduto)
    FROM (
        SELECT
            ProductKey,
            SUM(SalesAmount) AS FaturamentoProduto
        FROM dbo.FactSales
        WHERE YEAR(DateKey) = 2008
        GROUP BY ProductKey
    ) AS TotaisPorProduto
)
ORDER BY FaturamentoProduto DESC;

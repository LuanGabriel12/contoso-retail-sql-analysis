-- Análise 09 | ContosoRetailDW
-- Identificar os dez clientes com maior faturamento online em 2008 e contar seus pedidos distintos.

SELECT TOP (10)
    F.CustomerKey,
    YEAR(F.DateKey) AS Ano,
    SUM(F.SalesAmount) AS Faturamento,
    SUM(F.SalesQuantity) AS UnidadesCompradas,
    COUNT(DISTINCT F.SalesOrderNumber) AS QuantidadeDePedidos,
    C.CompanyName AS NomeDaEmpresa,
    C.CustomerType AS TipoDeCliente
FROM dbo.FactOnlineSales AS F
INNER JOIN dbo.DimCustomer AS C
    ON F.CustomerKey = C.CustomerKey
WHERE YEAR(F.DateKey) = 2008
GROUP BY YEAR(F.DateKey), F.CustomerKey, C.CompanyName, C.CustomerType
ORDER BY Faturamento DESC;

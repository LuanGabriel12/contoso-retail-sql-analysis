-- Análise 05 | ContosoRetailDW
-- Comparar faturamento, volume, lojas distintas e receita por unidade por tipo de loja em 2008.
-- Na base validada, StoreType corresponde a ChannelName no recorte de 2008.

SELECT
    YEAR(F.DateKey) AS Ano,
    SUM(F.SalesAmount) AS Faturamento,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    COUNT(DISTINCT S.StoreKey) AS QuantidadeDeLojas,
    S.StoreType AS TipoDaLoja,
    SUM(F.SalesAmount) / SUM(F.SalesQuantity) AS ReceitaPorUnidade
FROM dbo.FactSales AS F
INNER JOIN dbo.DimStore AS S
    ON S.StoreKey = F.StoreKey
WHERE YEAR(F.DateKey) = 2008
GROUP BY S.StoreType, YEAR(F.DateKey)
ORDER BY Faturamento DESC;

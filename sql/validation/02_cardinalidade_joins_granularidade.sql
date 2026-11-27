/*
================================================================================
ARQUIVO: sql/validation/02_cardinalidade_joins_granularidade.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Validação de Dados (Integridade Referencial e Anti-Fan-Out de JOINs)
================================================================================

1. PERGUNTA EMPRESARIAL
   Os relacionamentos 1:N entre as dimensões (DimDate, DimChannel, DimStore e
   DimProduct enriquecida com subcategoria e categoria) e a tabela fato
   FactSales preservam exatamente o número de linhas e os totais financeiros,
   sem registros órfãos e sem multiplicação (fan-out)?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimProduct
   - dbo.DimProductSubcategory
   - dbo.DimProductCategory
   - dbo.DimStore
   - dbo.DimChannel
   - dbo.DimDate
   - dbo.DimCurrency

3. LÓGICA DA CONSULTA
   - Bloco 1: Verifica chaves órfãs na FactSales via LEFT JOIN e contagem com
     CASE WHEN dimensão IS NULL.
   - Bloco 2: Verifica integridade da hierarquia snowflake de produtos
     (DimProduct -> DimProductSubcategory -> DimProductCategory) para garantir
     que a desnormalização no Power Query mantém cardinalidade exata 1:1 por
     ProductKey.
   - Bloco 3: Compara contagem de linhas, SalesAmount, TotalCost e SalesQuantity
     da FactSales isolada versus a mesma FactSales após todos os INNER JOINs do
     modelo estrela (teste anti-fan-out usando duas CTEs).
   - Bloco 4: Verifica uniformidade de moeda (DimCurrency), correspondência
     entre DimStore.StoreType e DimChannel.ChannelName e cobertura de catálogo
     (produtos sem vendas e lojas inativas com histórico de vendas).

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Chaves órfãs na FactSales: 0 (Produto, Loja, Canal e Data).
   - Hierarquia de produtos: 2.517 produtos -> 2.517 distintos após JOIN
     (0 sem subcategoria, 0 sem categoria), validando cardinalidade 1:1 para
     desnormalização da DimProduct no Power Query.
   - Teste anti-fan-out:
     * Linhas: 3.406.089 base vs. 3.406.089 após JOINs (diferença = 0)
     * Vendas: USD 12.413.657.608,8876 (diferença = 0,0000)
     * Custo:  USD 5.364.896.601,7800 (diferença = 0,0000)
     * Unidades: 53.320.454 (diferença = 0)
   - Moeda: 100% em USD (CurrencyKey = 1).
   - Alinhamento StoreType x ChannelName: correspondência 1:1 em 100% da fato
     (Store: 299 lojas; Online: 3; Reseller: 3; Catalog: 1).
   - Cobertura: 1 produto sem vendas na FactSales (ProductKey = 944);
     12 lojas com Status = 'Off' possuem vendas históricas (USD 272,58 milhões).

5. INTERPRETAÇÃO EMPRESARIAL
   Confirma que os relacionamentos 1:N no SQL e no Power BI não perdem vendas
   (0 órfãos) nem duplicam valores (diferença exatamente zero após JOINs).

6. POSSÍVEIS LIMITAÇÕES
   - A equivalência 1:1 entre StoreType e ChannelName é válida nos dados atuais
     da FactSales, mas a arquitetura usa DimChannel como fonte oficial de canal
     para evitar dependência de atributo cadastral da loja.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Integridade referencial: verificação de chaves órfãs na FactSales
-- -----------------------------------------------------------------------------
SELECT
    SUM(CASE WHEN P.ProductKey IS NULL THEN 1 ELSE 0 END) AS OrfaosProduto,
    SUM(CASE WHEN S.StoreKey IS NULL THEN 1 ELSE 0 END) AS OrfaosLoja,
    SUM(CASE WHEN CH.ChannelKey IS NULL THEN 1 ELSE 0 END) AS OrfaosCanal,
    SUM(CASE WHEN D.Datekey IS NULL THEN 1 ELSE 0 END) AS OrfaosData
FROM dbo.FactSales AS F
LEFT JOIN dbo.DimProduct AS P
    ON F.ProductKey = P.ProductKey
LEFT JOIN dbo.DimStore AS S
    ON F.StoreKey = S.StoreKey
LEFT JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
LEFT JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey;

-- -----------------------------------------------------------------------------
-- 2. Integridade da hierarquia de produtos (pré-requisito da desnormalização)
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS TotalProdutosCatalogo,
    COUNT(DISTINCT P.ProductKey) AS ProdutosDistintosAposJoin,
    SUM(CASE WHEN SC.ProductSubcategoryKey IS NULL THEN 1 ELSE 0 END) AS SemSubcategoria,
    SUM(CASE WHEN C.ProductCategoryKey IS NULL THEN 1 ELSE 0 END) AS SemCategoria
FROM dbo.DimProduct AS P
LEFT JOIN dbo.DimProductSubcategory AS SC
    ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
LEFT JOIN dbo.DimProductCategory AS C
    ON SC.ProductCategoryKey = C.ProductCategoryKey;

-- -----------------------------------------------------------------------------
-- 3. Teste anti-fan-out: FactSales isolada vs. modelo estrela completo
-- -----------------------------------------------------------------------------
WITH BaseFato AS (
    SELECT
        COUNT(*) AS LinhasBase,
        SUM(SalesAmount) AS VendasBase,
        SUM(TotalCost) AS CustoBase,
        SUM(SalesQuantity) AS UnidadesBase
    FROM dbo.FactSales
),
ModeloEstrela AS (
    SELECT
        COUNT(*) AS LinhasAposJoins,
        SUM(F.SalesAmount) AS VendasAposJoins,
        SUM(F.TotalCost) AS CustoAposJoins,
        SUM(F.SalesQuantity) AS UnidadesAposJoins
    FROM dbo.FactSales AS F
    INNER JOIN dbo.DimDate AS D
        ON F.DateKey = D.Datekey
    INNER JOIN dbo.DimChannel AS CH
        ON F.channelKey = CH.ChannelKey
    INNER JOIN dbo.DimStore AS S
        ON F.StoreKey = S.StoreKey
    INNER JOIN dbo.DimProduct AS P
        ON F.ProductKey = P.ProductKey
    INNER JOIN dbo.DimProductSubcategory AS SC
        ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
    INNER JOIN dbo.DimProductCategory AS C
        ON SC.ProductCategoryKey = C.ProductCategoryKey
)
SELECT
    B.LinhasBase,
    M.LinhasAposJoins,
    M.LinhasAposJoins - B.LinhasBase AS DiferencaLinhas,
    B.VendasBase,
    M.VendasAposJoins,
    M.VendasAposJoins - B.VendasBase AS DiferencaVendas,
    B.CustoBase,
    M.CustoAposJoins,
    M.CustoAposJoins - B.CustoBase AS DiferencaCusto,
    B.UnidadesBase,
    M.UnidadesAposJoins,
    M.UnidadesAposJoins - B.UnidadesBase AS DiferencaUnidades
FROM BaseFato AS B
INNER JOIN ModeloEstrela AS M
    ON 1 = 1;

-- -----------------------------------------------------------------------------
-- 4. Uniformidade de moeda, alinhamento StoreType x ChannelName e cobertura
-- -----------------------------------------------------------------------------
SELECT
    CUR.CurrencyKey,
    CUR.CurrencyName AS Moeda,
    COUNT(*) AS LinhasFactSales,
    SUM(F.SalesAmount) AS VendasTotais
FROM dbo.FactSales AS F
INNER JOIN dbo.DimCurrency AS CUR
    ON F.CurrencyKey = CUR.CurrencyKey
GROUP BY CUR.CurrencyKey, CUR.CurrencyName;

SELECT
    S.StoreType AS TipoLoja,
    CH.ChannelName AS Canal,
    COUNT(*) AS LinhasFactSales,
    COUNT(DISTINCT S.StoreKey) AS LojasDistintas
FROM dbo.FactSales AS F
INNER JOIN dbo.DimStore AS S
    ON F.StoreKey = S.StoreKey
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
GROUP BY S.StoreType, CH.ChannelName
ORDER BY LinhasFactSales DESC;

SELECT
    COUNT(*) AS ProdutosSemVendaNaFactSales
FROM dbo.DimProduct AS P
LEFT JOIN dbo.FactSales AS F
    ON P.ProductKey = F.ProductKey
WHERE F.ProductKey IS NULL;

SELECT
    S.Status AS StatusLoja,
    COUNT(DISTINCT S.StoreKey) AS LojasComVendas,
    SUM(F.SalesAmount) AS VendasTotais
FROM dbo.FactSales AS F
INNER JOIN dbo.DimStore AS S
    ON F.StoreKey = S.StoreKey
GROUP BY S.Status;

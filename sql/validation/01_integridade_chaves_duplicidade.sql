/*
================================================================================
ARQUIVO: sql/validation/01_integridade_chaves_duplicidade.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Validação de Dados (Qualidade, Chaves Primárias, Granularidade e Nulos)
================================================================================

1. PERGUNTA EMPRESARIAL
   As tabelas do modelo estrela (FactSales, DimProduct, DimProductSubcategory,
   DimProductCategory, DimStore, DimChannel e DimDate) possuem chaves únicas,
   granularidade íntegra e ausência de valores nulos nas colunas críticas para
   cálculo de faturamento, custo, lucro e margem comercial?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimProduct
   - dbo.DimProductSubcategory
   - dbo.DimProductCategory
   - dbo.DimStore
   - dbo.DimChannel
   - dbo.DimDate

3. LÓGICA DA CONSULTA
   - Bloco 1: Compara COUNT(*) e COUNT(DISTINCT Chave) em cada tabela para
     confirmar unicidade das chaves primárias.
   - Bloco 2: Agrupa FactSales pela chave primária (SalesKey) e pela chave
     composta de negócio (DateKey, channelKey, StoreKey, ProductKey,
     PromotionKey, CurrencyKey) com HAVING COUNT(*) > 1 para detectar duplicidade.
   - Bloco 3: Usa SUM(CASE WHEN ... IS NULL THEN 1 ELSE 0 END) para auditar
     nulos nas chaves estrangeiras e métricas financeiras da FactSales e na
     hierarquia de produtos.
   - Bloco 4: Verifica o período coberto pela FactSales e pela DimDate usando
     TOP (1) com ORDER BY ASC e DESC.

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Volumetria e unicidade (0 duplicatas de chave em todas as tabelas):
     * FactSales: 3.406.089 linhas | 3.406.089 SalesKey distintos
     * DimProduct: 2.517 linhas | DimProductSubcategory: 44 | DimProductCategory: 8
     * DimStore: 306 linhas | DimChannel: 4 | DimDate: 2.556 linhas
   - Duplicidade na granularidade composta da FactSales: 0 linhas retornadas.
   - Valores ausentes (NULL): 0 em todas as chaves e métricas financeiras da
     FactSales e nos atributos principais da DimProduct. Na DimStore, apenas
     CloseDate possui 294 nulos (correspondentes às 294 lojas com Status = 'On').
   - Cobertura temporal: FactSales de 2007-01-01 a 2009-12-31 (3 anos);
     DimDate de 2005-01-01 a 2011-12-31 (7 anos completos).

5. INTERPRETAÇÃO EMPRESARIAL
   Garante que as agregações de faturamento, custo e unidades não sofram
   inflação artificial por registros duplicados nem distorção por valores nulos.

6. POSSÍVEIS LIMITAÇÕES
   - Valida a estrutura presente na cópia local do ContosoRetailDW; alterações
     futuras de carga ETL exigiriam nova execução destes testes.
   - Não substitui auditoria de regras contábeis externas ao banco.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Volumetria e unicidade das chaves primárias
-- -----------------------------------------------------------------------------
SELECT
    'FactSales' AS Tabela,
    COUNT(*) AS TotalLinhas,
    COUNT(DISTINCT SalesKey) AS ChavesDistintas,
    COUNT(*) - COUNT(DISTINCT SalesKey) AS DuplicatasChave
FROM dbo.FactSales;

SELECT
    'DimProduct' AS Tabela,
    COUNT(*) AS TotalLinhas,
    COUNT(DISTINCT ProductKey) AS ChavesDistintas,
    COUNT(*) - COUNT(DISTINCT ProductKey) AS DuplicatasChave
FROM dbo.DimProduct;

SELECT
    'DimProductSubcategory' AS Tabela,
    COUNT(*) AS TotalLinhas,
    COUNT(DISTINCT ProductSubcategoryKey) AS ChavesDistintas,
    COUNT(*) - COUNT(DISTINCT ProductSubcategoryKey) AS DuplicatasChave
FROM dbo.DimProductSubcategory;

SELECT
    'DimProductCategory' AS Tabela,
    COUNT(*) AS TotalLinhas,
    COUNT(DISTINCT ProductCategoryKey) AS ChavesDistintas,
    COUNT(*) - COUNT(DISTINCT ProductCategoryKey) AS DuplicatasChave
FROM dbo.DimProductCategory;

SELECT
    'DimStore' AS Tabela,
    COUNT(*) AS TotalLinhas,
    COUNT(DISTINCT StoreKey) AS ChavesDistintas,
    COUNT(*) - COUNT(DISTINCT StoreKey) AS DuplicatasChave
FROM dbo.DimStore;

SELECT
    'DimChannel' AS Tabela,
    COUNT(*) AS TotalLinhas,
    COUNT(DISTINCT ChannelKey) AS ChavesDistintas,
    COUNT(*) - COUNT(DISTINCT ChannelKey) AS DuplicatasChave
FROM dbo.DimChannel;

SELECT
    'DimDate' AS Tabela,
    COUNT(*) AS TotalLinhas,
    COUNT(DISTINCT Datekey) AS ChavesDistintas,
    COUNT(*) - COUNT(DISTINCT Datekey) AS DuplicatasChave
FROM dbo.DimDate;

-- -----------------------------------------------------------------------------
-- 2. Auditoria de duplicidade na granularidade da FactSales
--    (Esperado: 0 linhas retornadas em ambas as consultas)
-- -----------------------------------------------------------------------------
SELECT
    SalesKey,
    COUNT(*) AS Ocorrencias
FROM dbo.FactSales
GROUP BY SalesKey
HAVING COUNT(*) > 1;

SELECT
    DateKey,
    channelKey,
    StoreKey,
    ProductKey,
    PromotionKey,
    CurrencyKey,
    COUNT(*) AS Ocorrencias
FROM dbo.FactSales
GROUP BY
    DateKey,
    channelKey,
    StoreKey,
    ProductKey,
    PromotionKey,
    CurrencyKey
HAVING COUNT(*) > 1;

-- -----------------------------------------------------------------------------
-- 3. Auditoria de valores ausentes (NULL) em colunas críticas
-- -----------------------------------------------------------------------------
SELECT
    SUM(CASE WHEN DateKey IS NULL THEN 1 ELSE 0 END) AS NulosDateKey,
    SUM(CASE WHEN channelKey IS NULL THEN 1 ELSE 0 END) AS NulosChannelKey,
    SUM(CASE WHEN StoreKey IS NULL THEN 1 ELSE 0 END) AS NulosStoreKey,
    SUM(CASE WHEN ProductKey IS NULL THEN 1 ELSE 0 END) AS NulosProductKey,
    SUM(CASE WHEN SalesAmount IS NULL THEN 1 ELSE 0 END) AS NulosSalesAmount,
    SUM(CASE WHEN TotalCost IS NULL THEN 1 ELSE 0 END) AS NulosTotalCost,
    SUM(CASE WHEN SalesQuantity IS NULL THEN 1 ELSE 0 END) AS NulosSalesQuantity
FROM dbo.FactSales;

SELECT
    SUM(CASE WHEN ProductName IS NULL THEN 1 ELSE 0 END) AS NulosProductName,
    SUM(CASE WHEN BrandName IS NULL THEN 1 ELSE 0 END) AS NulosBrandName,
    SUM(CASE WHEN ClassName IS NULL THEN 1 ELSE 0 END) AS NulosClassName,
    SUM(CASE WHEN ProductSubcategoryKey IS NULL THEN 1 ELSE 0 END) AS NulosSubcategoryKey,
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS NulosUnitPrice,
    SUM(CASE WHEN UnitCost IS NULL THEN 1 ELSE 0 END) AS NulosUnitCost
FROM dbo.DimProduct;

SELECT
    SUM(CASE WHEN StoreName IS NULL THEN 1 ELSE 0 END) AS NulosStoreName,
    SUM(CASE WHEN StoreType IS NULL THEN 1 ELSE 0 END) AS NulosStoreType,
    SUM(CASE WHEN Status IS NULL THEN 1 ELSE 0 END) AS NulosStatus,
    SUM(CASE WHEN OpenDate IS NULL THEN 1 ELSE 0 END) AS NulosOpenDate,
    SUM(CASE WHEN CloseDate IS NULL THEN 1 ELSE 0 END) AS NulosCloseDate
FROM dbo.DimStore;

-- -----------------------------------------------------------------------------
-- 4. Cobertura temporal da FactSales e da DimDate
-- -----------------------------------------------------------------------------
SELECT TOP (1)
    'FactSales - Primeira Data' AS Verificacao,
    DateKey AS DataReferencia
FROM dbo.FactSales
ORDER BY DateKey ASC;

SELECT TOP (1)
    'FactSales - Ultima Data' AS Verificacao,
    DateKey AS DataReferencia
FROM dbo.FactSales
ORDER BY DateKey DESC;

SELECT TOP (1)
    'DimDate - Primeira Data' AS Verificacao,
    Datekey AS DataReferencia
FROM dbo.DimDate
ORDER BY Datekey ASC;

SELECT TOP (1)
    'DimDate - Ultima Data' AS Verificacao,
    Datekey AS DataReferencia
FROM dbo.DimDate
ORDER BY Datekey DESC;

/*
================================================================================
ARQUIVO: sql/commercial_analysis/05_desempenho_canais_e_mix_comercial.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Análise Comercial (Desempenho por Canal e Evolução Canal x Ano)
================================================================================

1. PERGUNTA EMPRESARIAL
   Como faturamento, lucro comercial, margem, volume de unidades e receita por
   unidade se distribuem entre os quatro canais (Store, Online, Reseller e
   Catalog), e como cada canal evoluiu entre 2007, 2008 e 2009?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimChannel
   - dbo.DimDate
   - dbo.DimStore

3. LÓGICA DA CONSULTA
   - Consulta 1 (Desempenho Consolidado por Canal): Usa CTE (ResumoCanais) +
     subconsulta escalar para calcular participação percentual em vendas e
     lucro, lojas distintas, faturamento médio por loja e receita por unidade.
   - Consulta 2 (Evolução Anual por Canal): Mostra a trajetória de cada canal
     entre 2007, 2008 e 2009, incluindo receita por unidade para investigar a
     queda de faturamento acompanhada de alta de unidades em 2009.
   - Consulta 3 (Investigação do Mix 2009 por Categoria): Compara faturamento,
     unidades e receita por unidade das categorias por ano para explicar o
     fenômeno de alta de volume com queda de faturamento em 2009.

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Consolidado por Canal (2007-2009):
     * Store:    USD 6,94 bi (55,93%) | 299 lojas | Margem 56,90% | USD 238,67/un. | USD 23,22 mi/loja
     * Online:   USD 2,68 bi (21,57%) |   3 lojas | Margem 56,55% | USD 214,10/un. | USD 892,53 mi/loja
     * Reseller: USD 1,72 bi (13,82%) |   3 lojas | Margem 56,65% | USD 235,91/un. | USD 571,73 mi/loja
     * Catalog:  USD 1,08 bi ( 8,68%) |   1 loja  | Margem 56,82% | USD 242,01/un. | USD 1,08 bi/loja
   - Evolução Anual por Canal:
     * Online foi o único canal com crescimento contínuo de receita (USD 789,38 mi
       -> USD 937,07 mi -> USD 951,15 mi), quase dobrando o volume (2,99 mi ->
       5,57 mi unidades).
     * Store retraiu de USD 2,78 bi (2007) para USD 1,93 bi (2009).
   - Explicação da dinâmica 2009 (alta de volume com queda de receita):
     * Cell phones saltou de 3,93 mi para 5,77 mi unidades com receita/unidade
       caindo de USD 64,88 para USD 47,39; Games and Toys subiu para 2,46 mi un.
       (~USD 26,59/un.); Home Appliances e Cameras reduziram ticket médio unitário.

5. INTERPRETAÇÃO EMPRESARIAL
   Mostra o papel complementar dos canais (capilaridade física do Store vs.
   alta concentração de receita por unidade em Online, Reseller e Catalog) e
   investiga numericamente a dinâmica de preço/volume entre 2007 e 2009.

6. POSSÍVEIS LIMITAÇÕES
   - As vendas do canal Online nesta análise vêm de dbo.FactSales (agregadas
     por loja/produto/dia), distintas da tabela transacional dbo.FactOnlineSales.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Desempenho Consolidado por Canal (2007-2009)
-- -----------------------------------------------------------------------------
WITH ResumoCanais AS (
    SELECT
        CH.ChannelKey,
        CH.ChannelName AS Canal,
        COUNT(DISTINCT F.StoreKey) AS LojasComVendas,
        SUM(F.SalesAmount) AS VendasTotais,
        SUM(F.TotalCost) AS CustoTotal,
        SUM(F.SalesQuantity) AS UnidadesVendidas,
        SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial
    FROM dbo.FactSales AS F
    INNER JOIN dbo.DimChannel AS CH
        ON F.channelKey = CH.ChannelKey
    GROUP BY CH.ChannelKey, CH.ChannelName
)
SELECT
    Canal,
    LojasComVendas,
    VendasTotais,
    CustoTotal,
    LucroComercial,
    UnidadesVendidas,
    CAST(
        CAST(LucroComercial AS DECIMAL(18, 6))
            / NULLIF(VendasTotais, 0) * 100
        AS DECIMAL(10, 2)
    ) AS MargemComercialPct,
    CAST(
        CAST(VendasTotais AS DECIMAL(18, 6))
            / NULLIF((SELECT SUM(VendasTotais) FROM ResumoCanais), 0) * 100
        AS DECIMAL(10, 2)
    ) AS ParticipacaoVendasPct,
    CAST(
        CAST(VendasTotais AS DECIMAL(18, 6))
            / NULLIF(UnidadesVendidas, 0)
        AS DECIMAL(18, 2)
    ) AS ReceitaPorUnidade,
    CAST(
        CAST(VendasTotais AS DECIMAL(18, 6))
            / NULLIF(LojasComVendas, 0)
        AS DECIMAL(18, 2)
    ) AS VendaMediaPorLoja
FROM ResumoCanais
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- 2. Evolução Anual por Canal (2007-2009)
-- -----------------------------------------------------------------------------
SELECT
    D.CalendarYear AS Ano,
    CH.ChannelName AS Canal,
    COUNT(DISTINCT F.StoreKey) AS LojasComVendas,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0) * 100
        AS DECIMAL(10, 2)
    ) AS MargemComercialPct,
    CAST(
        CAST(SUM(F.SalesAmount) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesQuantity), 0)
        AS DECIMAL(18, 2)
    ) AS ReceitaPorUnidade
FROM dbo.FactSales AS F
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
GROUP BY D.CalendarYear, CH.ChannelName
ORDER BY CH.ChannelName, D.CalendarYear;

-- -----------------------------------------------------------------------------
-- 3. Evolução Anual por Categoria (Investigação do Volume x Receita 2007-2009)
-- -----------------------------------------------------------------------------
SELECT
    D.CalendarYear AS Ano,
    C.ProductCategoryName AS Categoria,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    CAST(
        CAST(SUM(F.SalesAmount) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesQuantity), 0)
        AS DECIMAL(18, 2)
    ) AS ReceitaPorUnidade,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0) * 100
        AS DECIMAL(10, 2)
    ) AS MargemComercialPct
FROM dbo.FactSales AS F
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
INNER JOIN dbo.DimProduct AS P
    ON F.ProductKey = P.ProductKey
INNER JOIN dbo.DimProductSubcategory AS SC
    ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
INNER JOIN dbo.DimProductCategory AS C
    ON SC.ProductCategoryKey = C.ProductCategoryKey
GROUP BY D.CalendarYear, C.ProductCategoryName
ORDER BY C.ProductCategoryName, D.CalendarYear;

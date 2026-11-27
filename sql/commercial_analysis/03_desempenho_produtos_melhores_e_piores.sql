/*
================================================================================
ARQUIVO: sql/commercial_analysis/03_desempenho_produtos_melhores_e_piores.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Análise Comercial (Melhores e Piores Produtos + Top 3 por Categoria)
================================================================================

1. PERGUNTA EMPRESARIAL
   Quais produtos apresentaram os melhores e piores resultados comerciais em
   faturamento e lucro, quais lideram dentro de cada categoria e há itens do
   catálogo sem nenhuma venda registrada na FactSales?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimProduct
   - dbo.DimProductSubcategory
   - dbo.DimProductCategory

3. LÓGICA DA CONSULTA
   - Consulta 1 (Top 10 Produtos por Faturamento): Lista os líderes globais em
     receita, unidades, lucro comercial e margem ponderada.
   - Consulta 2 (Bottom 10 Produtos Vendidos por Faturamento): Identifica os
     dez itens com vendas registradas que geraram menor faturamento total.
   - Consulta 3 (Top 3 Produtos por Categoria): Usa CTE + ROW_NUMBER() OVER
     (PARTITION BY Categoria ORDER BY VendasTotais DESC) — uso justificado de
     função de janela para ranquear líderes dentro de cada grupo.
   - Consulta 4 (Produtos do Catálogo sem Vendas): Usa LEFT JOIN + IS NULL para
     incluir o caso extremo de desempenho comercial nulo na FactSales.

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Top 10 Produtos: 9 dos 10 líderes são projetores 1080p da categoria
     Computers (margem ~66,7%), liderados por Proseware Projector 1080p DLP86
     White (ProductKey 552, USD 51,90 mi vendas, USD 34,62 mi lucro, 66,71%
     margem). Em 10º aparece Litware Refrigerator 24.7CuFt X980 Grey (USD 45,63 mi).
   - Bottom 10 Produtos Vendidos: dominados por cabos USB da marca Southridge
     Video (Computers), com menor faturamento no SV USB Data Cable E600 Pink
     (ProductKey 919, USD 14.982,17 em 16.006 unidades, margem 48,94%).
   - Top 3 por Categoria: 24 registros (3 por cada uma das 8 categorias),
     evidenciando a concentração de modelos com variações de cor nos líderes.
   - Catálogo sem vendas na FactSales: exatamente 1 produto — ProductKey 944
     (A. Datum Compact Digital Camera M200 Black, USD 129,00).

5. INTERPRETAÇÃO EMPRESARIAL
   Evidencia quais SKUs concentram maior geração de caixa e margem, quais itens
   possuem baixo retorno monetário (mesmo vendendo milhares de unidades) e quais
   produtos ativos em catálogo não converteram vendas na FactSales.

6. POSSÍVEIS LIMITAÇÕES
   - A análise considera apenas dbo.FactSales; produtos sem venda aqui podem
     ter movimentação em dbo.FactOnlineSales.
   - Produtos lançados mais tarde ou descontinuados mais cedo podem ter menos
     meses de exposição comercial.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Top 10 Produtos com Maior Faturamento (2007-2009)
-- -----------------------------------------------------------------------------
SELECT TOP (10)
    P.ProductKey,
    P.ProductName AS Produto,
    P.BrandName AS Marca,
    C.ProductCategoryName AS Categoria,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0) * 100
        AS DECIMAL(10, 2)
    ) AS MargemComercialPct
FROM dbo.FactSales AS F
INNER JOIN dbo.DimProduct AS P
    ON F.ProductKey = P.ProductKey
INNER JOIN dbo.DimProductSubcategory AS SC
    ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
INNER JOIN dbo.DimProductCategory AS C
    ON SC.ProductCategoryKey = C.ProductCategoryKey
GROUP BY P.ProductKey, P.ProductName, P.BrandName, C.ProductCategoryName
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- 2. Bottom 10 Produtos Vendidos com Menor Faturamento (2007-2009)
-- -----------------------------------------------------------------------------
SELECT TOP (10)
    P.ProductKey,
    P.ProductName AS Produto,
    P.BrandName AS Marca,
    C.ProductCategoryName AS Categoria,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0) * 100
        AS DECIMAL(10, 2)
    ) AS MargemComercialPct
FROM dbo.FactSales AS F
INNER JOIN dbo.DimProduct AS P
    ON F.ProductKey = P.ProductKey
INNER JOIN dbo.DimProductSubcategory AS SC
    ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
INNER JOIN dbo.DimProductCategory AS C
    ON SC.ProductCategoryKey = C.ProductCategoryKey
GROUP BY P.ProductKey, P.ProductName, P.BrandName, C.ProductCategoryName
ORDER BY VendasTotais ASC;

-- -----------------------------------------------------------------------------
-- 3. Top 3 Produtos por Categoria (ROW_NUMBER + PARTITION BY)
-- -----------------------------------------------------------------------------
WITH VendasPorProduto AS (
    SELECT
        C.ProductCategoryName AS Categoria,
        P.ProductKey,
        P.ProductName AS Produto,
        SUM(F.SalesAmount) AS VendasTotais,
        SUM(F.SalesQuantity) AS UnidadesVendidas,
        SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
        CAST(
            CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
                / NULLIF(SUM(F.SalesAmount), 0) * 100
            AS DECIMAL(10, 2)
        ) AS MargemComercialPct
    FROM dbo.FactSales AS F
    INNER JOIN dbo.DimProduct AS P
        ON F.ProductKey = P.ProductKey
    INNER JOIN dbo.DimProductSubcategory AS SC
        ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
    INNER JOIN dbo.DimProductCategory AS C
        ON SC.ProductCategoryKey = C.ProductCategoryKey
    GROUP BY C.ProductCategoryName, P.ProductKey, P.ProductName
),
RankingPorCategoria AS (
    SELECT
        Categoria,
        ProductKey,
        Produto,
        VendasTotais,
        UnidadesVendidas,
        LucroComercial,
        MargemComercialPct,
        ROW_NUMBER() OVER (
            PARTITION BY Categoria
            ORDER BY VendasTotais DESC, ProductKey ASC
        ) AS PosicaoNaCategoria
    FROM VendasPorProduto
)
SELECT
    Categoria,
    PosicaoNaCategoria,
    ProductKey,
    Produto,
    VendasTotais,
    LucroComercial,
    MargemComercialPct
FROM RankingPorCategoria
WHERE PosicaoNaCategoria <= 3
ORDER BY Categoria, PosicaoNaCategoria;

-- -----------------------------------------------------------------------------
-- 4. Produtos do Catálogo sem Nenhuma Venda Registrada na FactSales
-- -----------------------------------------------------------------------------
SELECT
    P.ProductKey,
    P.ProductName AS Produto,
    P.BrandName AS Marca,
    C.ProductCategoryName AS Categoria,
    P.UnitPrice AS PrecoCatalogo,
    P.UnitCost AS CustoCatalogo
FROM dbo.DimProduct AS P
INNER JOIN dbo.DimProductSubcategory AS SC
    ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
INNER JOIN dbo.DimProductCategory AS C
    ON SC.ProductCategoryKey = C.ProductCategoryKey
LEFT JOIN dbo.FactSales AS F
    ON P.ProductKey = F.ProductKey
WHERE F.ProductKey IS NULL;

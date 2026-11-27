/*
================================================================================
ARQUIVO: sql/commercial_analysis/02_desempenho_categorias_e_subcategorias.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Análise Comercial (Desempenho por Categoria e Subcategoria)
================================================================================

1. PERGUNTA EMPRESARIAL
   Qual a participação de cada categoria de produto no faturamento, no lucro
   comercial, no volume vendido e na margem comercial, e quais subcategorias
   lideram ou ficam abaixo na geração de resultado?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimProduct
   - dbo.DimProductSubcategory
   - dbo.DimProductCategory

3. LÓGICA DA CONSULTA
   - Consulta 1 (Desempenho por Categoria): Usa uma CTE (ResumoCategorias) e
     subconsultas escalares sobre a própria CTE para calcular a participação
     percentual de cada categoria no faturamento e no lucro totais, além de
     classificar a margem via CASE WHEN.
   - Consulta 2 (Top 10 Subcategorias por Faturamento): Detalha as subcategorias
     mais relevantes em geração de receita e lucro.
   - Consulta 3 (Bottom 10 Subcategorias por Faturamento): Identifica as
     subcategorias de menor expressão comercial no portfólio.

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Desempenho por Categoria (8 categorias):
     * 1º Home Appliances: USD 3,92 bi (31,60% vendas | 55,56% margem | USD 377,93/un.)
     * 2º Computers: USD 3,21 bi (25,85% vendas | 56,87% margem | USD 303,82/un.)
     * 3º Cameras and camcorders: USD 2,56 bi (20,64% vendas | 59,99% margem | USD 391,08/un.)
     * 4º TV and Video: USD 1,36 bi (10,96% | 54,59% margem)
     * 5º Cell phones: USD 892,23 mi (7,19% | 13,46 mi un. — líder em volume | USD 66,29/un.)
     * 6º Music, Movies and Audio Books: USD 165,80 mi (1,34% | maior margem: 60,84%)
     * 7º Audio: USD 151,61 mi (1,22% | 57,21% margem)
     * 8º Games and Toys: USD 149,70 mi (1,21% | menor margem: 53,75% | USD 24,78/un.)
   - Top 3 categorias concentram 78,09% do faturamento total.
   - Subcategorias: líder Camcorders (USD 1,34 bi; 59,83% margem), seguida de
     Projectors & Screens (USD 1,11 bi; 59,75%) e Washers & Dryers (USD 1,07 bi;
     52,98%). Menor faturamento: Boxed Games (USD 32,44 mi em 3,72 mi unidades).

5. INTERPRETAÇÃO EMPRESARIAL
   Separa categorias de alto volume/ticket baixo (como Cell phones) de
   categorias âncora de receita (Home Appliances, Computers) e categorias de
   alta margem (Music, Movies and Audio Books; Cameras and camcorders).

6. POSSÍVEIS LIMITAÇÕES
   - A categoria 'Cameras and camcorders ' possui um espaço em branco ao final
     do texto na tabela original dbo.DimProductCategory (tratado via Power Query
     no modelo Power BI).
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Desempenho Comercial por Categoria (com participação percentual)
-- -----------------------------------------------------------------------------
WITH ResumoCategorias AS (
    SELECT
        C.ProductCategoryKey,
        C.ProductCategoryName AS Categoria,
        COUNT(DISTINCT P.ProductKey) AS ProdutosVendidos,
        SUM(F.SalesAmount) AS VendasTotais,
        SUM(F.TotalCost) AS CustoTotal,
        SUM(F.SalesQuantity) AS UnidadesVendidas,
        SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial
    FROM dbo.FactSales AS F
    INNER JOIN dbo.DimProduct AS P
        ON F.ProductKey = P.ProductKey
    INNER JOIN dbo.DimProductSubcategory AS SC
        ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
    INNER JOIN dbo.DimProductCategory AS C
        ON SC.ProductCategoryKey = C.ProductCategoryKey
    GROUP BY C.ProductCategoryKey, C.ProductCategoryName
)
SELECT
    Categoria,
    ProdutosVendidos,
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
            / NULLIF((SELECT SUM(VendasTotais) FROM ResumoCategorias), 0) * 100
        AS DECIMAL(10, 2)
    ) AS ParticipacaoVendasPct,
    CAST(
        CAST(LucroComercial AS DECIMAL(18, 6))
            / NULLIF((SELECT SUM(LucroComercial) FROM ResumoCategorias), 0) * 100
        AS DECIMAL(10, 2)
    ) AS ParticipacaoLucroPct,
    CAST(
        CAST(VendasTotais AS DECIMAL(18, 6))
            / NULLIF(UnidadesVendidas, 0)
        AS DECIMAL(18, 2)
    ) AS ReceitaPorUnidade,
    CASE
        WHEN CAST(LucroComercial AS DECIMAL(18, 6)) / NULLIF(VendasTotais, 0) >= 0.59
            THEN 'Margem Alta (>= 59%)'
        WHEN CAST(LucroComercial AS DECIMAL(18, 6)) / NULLIF(VendasTotais, 0) >= 0.56
            THEN 'Margem Intermediaria (56% a 58,99%)'
        ELSE 'Margem Inferior (< 56%)'
    END AS FaixaMargem
FROM ResumoCategorias
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- 2. Top 10 Subcategorias por Faturamento
-- -----------------------------------------------------------------------------
SELECT TOP (10)
    C.ProductCategoryName AS Categoria,
    SC.ProductSubcategoryName AS Subcategoria,
    COUNT(DISTINCT P.ProductKey) AS ProdutosVendidos,
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
GROUP BY C.ProductCategoryName, SC.ProductSubcategoryName
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- 3. Bottom 10 Subcategorias por Faturamento
-- -----------------------------------------------------------------------------
SELECT TOP (10)
    C.ProductCategoryName AS Categoria,
    SC.ProductSubcategoryName AS Subcategoria,
    COUNT(DISTINCT P.ProductKey) AS ProdutosVendidos,
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
GROUP BY C.ProductCategoryName, SC.ProductSubcategoryName
ORDER BY VendasTotais ASC;

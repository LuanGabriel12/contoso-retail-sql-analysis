/*
================================================================================
ARQUIVO: sql/kpis/02_matriz_reconciliacao_powerbi.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  KPIs e Reconciliação Independente SQL vs. Power BI (DAX)
================================================================================

1. PERGUNTA EMPRESARIAL
   Os valores exibidos pelos cartões, tabelas e filtros do Power BI coincidem
   exatamente com consultas SQL independentes no total geral e nos recortes
   combinados de ano, canal, categoria, produto e loja?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimDate
   - dbo.DimChannel
   - dbo.DimProduct
   - dbo.DimProductSubcategory
   - dbo.DimProductCategory
   - dbo.DimStore

3. LÓGICA DA CONSULTA
   Gera seis tabelas de controle independentes para batimento 1:1 com DAX:
   - Controle 1: Total geral sem filtros (cartões da Página 1).
   - Controle 2: Recorte por Ano (propagação de filtro DimDate -> FactSales).
   - Controle 3: Recorte por Canal (propagação DimChannel -> FactSales).
   - Controle 4: Recorte por Categoria (propagação DimProduct -> FactSales).
   - Controle 5: Recorte combinado multidimensional (Ano = 2008 e
     Canal = 'Online', testando filtros simultâneos de duas dimensões).
   - Controle 6: Recorte combinado de três dimensões (Ano = 2009,
     Canal = 'Store' e Categoria = 'Computers').

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Controle 1 (Geral): Vendas 12.413.657.608,8876 | Custo 5.364.896.601,7800 |
     Unidades 53.320.454 | Lucro 7.048.761.007,1076 | Margem 0,567823 (56,78%).
   - Controle 2 (Ano): 2007 (4,56 bi / 56,88%), 2008 (4,11 bi / 56,87%),
     2009 (3,74 bi / 56,57%).
   - Controle 3 (Canal): Store (6,94 bi / 56,90%), Online (2,68 bi / 56,55%),
     Reseller (1,72 bi / 56,65%), Catalog (1,08 bi / 56,82%).
   - Controle 4 (Categoria): 8 categorias variando de Home Appliances (3,92 bi /
     55,56%) até Games and Toys (149,70 mi / 53,75%).
   - Controle 5 (2008 + Online): Vendas 937.069.110,9298 | Custo 406.631.362,1600 |
     Unidades 3.942.776 | Lucro 530.437.748,7698 | Margem 0,566060 (56,61%).
   - Controle 6 (2009 + Store + Computers): Vendas 617.083.601,3369 |
     Custo 267.484.833,9600 | Unidades 2.099.168 | Lucro 349.598.767,3769 |
     Margem 0,566534 (56,65%).

5. INTERPRETAÇÃO EMPRESARIAL
   Permite auditar com rigor se o modelo estrela no Power BI propaga filtros
   corretamente das dimensões para a tabela fato e se as medidas DAX produzem
   números idênticos ao banco de dados de origem.

6. POSSÍVEIS LIMITAÇÕES
   - Diferenças mínimas na última casa decimal podem ocorrer apenas por
     arredondamento visual na formatação dos cartões; a comparação oficial
     deve conferir os valores completos com duas a quatro casas decimais.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- Controle 1: Total Geral (sem filtros)
-- -----------------------------------------------------------------------------
SELECT
    SUM(SalesAmount) AS VendasTotais,
    SUM(TotalCost) AS CustoTotal,
    SUM(SalesQuantity) AS UnidadesVendidas,
    SUM(SalesAmount) - SUM(TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(SalesAmount) - SUM(TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(SalesAmount), 0)
        AS DECIMAL(10, 6)
    ) AS MargemComercialDecimal
FROM dbo.FactSales;

-- -----------------------------------------------------------------------------
-- Controle 2: Por Ano (DimDate)
-- -----------------------------------------------------------------------------
SELECT
    D.CalendarYear AS Ano,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0)
        AS DECIMAL(10, 6)
    ) AS MargemComercialDecimal
FROM dbo.FactSales AS F
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
GROUP BY D.CalendarYear
ORDER BY D.CalendarYear;

-- -----------------------------------------------------------------------------
-- Controle 3: Por Canal (DimChannel)
-- -----------------------------------------------------------------------------
SELECT
    CH.ChannelName AS Canal,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0)
        AS DECIMAL(10, 6)
    ) AS MargemComercialDecimal
FROM dbo.FactSales AS F
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
GROUP BY CH.ChannelName
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- Controle 4: Por Categoria (DimProduct desnormalizada)
-- -----------------------------------------------------------------------------
SELECT
    C.ProductCategoryName AS Categoria,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0)
        AS DECIMAL(10, 6)
    ) AS MargemComercialDecimal
FROM dbo.FactSales AS F
INNER JOIN dbo.DimProduct AS P
    ON F.ProductKey = P.ProductKey
INNER JOIN dbo.DimProductSubcategory AS SC
    ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
INNER JOIN dbo.DimProductCategory AS C
    ON SC.ProductCategoryKey = C.ProductCategoryKey
GROUP BY C.ProductCategoryName
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- Controle 5: Filtro combinado 2D (Ano = 2008 e Canal = Online)
-- -----------------------------------------------------------------------------
SELECT
    D.CalendarYear AS Ano,
    CH.ChannelName AS Canal,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0)
        AS DECIMAL(10, 6)
    ) AS MargemComercialDecimal
FROM dbo.FactSales AS F
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
WHERE D.CalendarYear = 2008
    AND CH.ChannelName = 'Online'
GROUP BY D.CalendarYear, CH.ChannelName;

-- -----------------------------------------------------------------------------
-- Controle 6: Filtro combinado 3D (Ano = 2009, Canal = Store, Categoria = Computers)
-- -----------------------------------------------------------------------------
SELECT
    D.CalendarYear AS Ano,
    CH.ChannelName AS Canal,
    C.ProductCategoryName AS Categoria,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.TotalCost) AS CustoTotal,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0)
        AS DECIMAL(10, 6)
    ) AS MargemComercialDecimal
FROM dbo.FactSales AS F
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
INNER JOIN dbo.DimProduct AS P
    ON F.ProductKey = P.ProductKey
INNER JOIN dbo.DimProductSubcategory AS SC
    ON P.ProductSubcategoryKey = SC.ProductSubcategoryKey
INNER JOIN dbo.DimProductCategory AS C
    ON SC.ProductCategoryKey = C.ProductCategoryKey
WHERE D.CalendarYear = 2009
    AND CH.ChannelName = 'Store'
    AND C.ProductCategoryName = 'Computers'
GROUP BY D.CalendarYear, CH.ChannelName, C.ProductCategoryName;

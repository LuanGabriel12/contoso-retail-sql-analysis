/*
================================================================================
ARQUIVO: sql/commercial_analysis/04_desempenho_lojas_melhores_e_piores.sql
PROJETO: Contoso Business Intelligence V2 (ContosoRetailDW)
CAMADA:  Análise Comercial (Melhores e Piores Lojas + Top 3 por Canal)
================================================================================

1. PERGUNTA EMPRESARIAL
   Quais lojas apresentaram os melhores e piores desempenhos comerciais no
   período 2007-2009, como esse ranking muda quando comparamos apenas lojas
   físicas ('Store') e qual o impacto dos meses efetivos de operação e do
   status da loja (On/Off)?

2. TABELAS UTILIZADAS
   - dbo.FactSales
   - dbo.DimStore
   - dbo.DimChannel
   - dbo.DimDate

3. LÓGICA DA CONSULTA
   - Consulta 1 (Top 10 Lojas Gerais): Identifica as dez maiores unidades por
     faturamento, trazendo canal, status e quantidade de meses distintos com
     venda (COUNT(DISTINCT D.CalendarMonth)) para contextualizar maturidade.
   - Consulta 2 (Bottom 10 Lojas Gerais): Identifica as dez unidades com menor
     faturamento e evidencia se o baixo volume decorre de operação parcial
     (poucos meses ativos) ou de baixa produtividade mensal média.
   - Consulta 3 (Top 10 Lojas Físicas - Canal 'Store'): Isola o canal Store para
     comparar lojas físicas entre si de forma justa (sem misturar com centros
     regionais Online, Catalog e Reseller).
   - Consulta 4 (Top 3 Lojas por Canal): Usa CTE + ROW_NUMBER() OVER
     (PARTITION BY Canal ORDER BY VendasTotais DESC).

4. RESULTADO OBTIDO (VERIFICADO EM SQL SERVER — ContosoRetailDW)
   - Top 10 Lojas Gerais: as 7 primeiras são unidades centralizadas (1 Catalog,
     3 Online e 3 Reseller), lideradas por Contoso Catalog Store (StoreKey 200,
     USD 1,08 bi em 36 meses) e Contoso North America Online Store (StoreKey 199,
     USD 984,25 mi). A 1ª loja física aparece em 8º: Contoso Sydney No.1 Store
     (StoreKey 253, USD 37,93 mi, 56,88% margem).
   - Bottom 10 Lojas Gerais: menor faturamento acumulado em Contoso Venezia Store
     (StoreKey 223, USD 1,77 mi em 12 meses ativos, média USD 147,75 mil/mês) e
     Contoso Racine No.2 Store (StoreKey 65, USD 2,64 mi em 12 meses). Já Contoso
     Kyoto Store (3ª menor no acumulado, USD 4,69 mi) teve apenas 8 meses ativos,
     mas média mensal de USD 586,79 mil/mês (quase 4x a de Venezia).
   - Top 10 Lojas Físicas ('Store'): variam entre USD 37,93 mi (Sydney No.1) e
     USD 37,43 mi (Moscow No.2), todas com 36 meses ativos e margem entre 56,58%
     e 57,06%.
   - Top 3 por Canal: 10 linhas (Catalog possui 1 unidade; Online 3; Reseller 3;
     Store exibe o pódio Sydney No.1, Tehran No.2 e Sydney No.2).

5. INTERPRETAÇÃO EMPRESARIAL
   Evita conclusões equivocadas ao distinguir unidades centralizadas (Catalog,
   Online e Reseller) de lojas físicas individuais e ao ponderar faturamento
   total pelo número de meses com vendas efetivas.

6. POSSÍVEIS LIMITAÇÕES
   - A base contém 12 lojas com Status = 'Off' que ainda possuem histórico de
     vendas nos anos anteriores ao encerramento.
   - Não considera custos fixos de aluguel, folha salarial ou área de venda no
     cálculo do lucro comercial.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. Top 10 Lojas Gerais por Faturamento (2007-2009)
-- -----------------------------------------------------------------------------
SELECT TOP (10)
    S.StoreKey,
    S.StoreName AS Loja,
    CH.ChannelName AS Canal,
    S.Status AS StatusLoja,
    COUNT(DISTINCT D.CalendarMonth) AS MesesComVenda,
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
            / NULLIF(COUNT(DISTINCT D.CalendarMonth), 0)
        AS DECIMAL(18, 2)
    ) AS VendaMediaPorMesAtivo
FROM dbo.FactSales AS F
INNER JOIN dbo.DimStore AS S
    ON F.StoreKey = S.StoreKey
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
GROUP BY S.StoreKey, S.StoreName, CH.ChannelName, S.Status
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- 2. Bottom 10 Lojas Gerais por Faturamento (2007-2009)
-- -----------------------------------------------------------------------------
SELECT TOP (10)
    S.StoreKey,
    S.StoreName AS Loja,
    CH.ChannelName AS Canal,
    S.Status AS StatusLoja,
    S.OpenDate AS DataAbertura,
    S.CloseDate AS DataFechamento,
    COUNT(DISTINCT D.CalendarMonth) AS MesesComVenda,
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
            / NULLIF(COUNT(DISTINCT D.CalendarMonth), 0)
        AS DECIMAL(18, 2)
    ) AS VendaMediaPorMesAtivo
FROM dbo.FactSales AS F
INNER JOIN dbo.DimStore AS S
    ON F.StoreKey = S.StoreKey
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
GROUP BY
    S.StoreKey,
    S.StoreName,
    CH.ChannelName,
    S.Status,
    S.OpenDate,
    S.CloseDate
ORDER BY VendasTotais ASC;

-- -----------------------------------------------------------------------------
-- 3. Top 10 Lojas Físicas (Canal = 'Store') por Faturamento
-- -----------------------------------------------------------------------------
SELECT TOP (10)
    S.StoreKey,
    S.StoreName AS LojaFisica,
    S.Status AS StatusLoja,
    COUNT(DISTINCT D.CalendarMonth) AS MesesComVenda,
    SUM(F.SalesAmount) AS VendasTotais,
    SUM(F.SalesQuantity) AS UnidadesVendidas,
    SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
    CAST(
        CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
            / NULLIF(SUM(F.SalesAmount), 0) * 100
        AS DECIMAL(10, 2)
    ) AS MargemComercialPct
FROM dbo.FactSales AS F
INNER JOIN dbo.DimStore AS S
    ON F.StoreKey = S.StoreKey
INNER JOIN dbo.DimChannel AS CH
    ON F.channelKey = CH.ChannelKey
INNER JOIN dbo.DimDate AS D
    ON F.DateKey = D.Datekey
WHERE CH.ChannelName = 'Store'
GROUP BY S.StoreKey, S.StoreName, S.Status
ORDER BY VendasTotais DESC;

-- -----------------------------------------------------------------------------
-- 4. Top 3 Unidades por Canal (ROW_NUMBER + PARTITION BY)
-- -----------------------------------------------------------------------------
WITH VendasPorLojaCanal AS (
    SELECT
        CH.ChannelName AS Canal,
        S.StoreKey,
        S.StoreName AS Loja,
        S.Status AS StatusLoja,
        SUM(F.SalesAmount) AS VendasTotais,
        SUM(F.SalesAmount) - SUM(F.TotalCost) AS LucroComercial,
        CAST(
            CAST((SUM(F.SalesAmount) - SUM(F.TotalCost)) AS DECIMAL(18, 6))
                / NULLIF(SUM(F.SalesAmount), 0) * 100
            AS DECIMAL(10, 2)
        ) AS MargemComercialPct
    FROM dbo.FactSales AS F
    INNER JOIN dbo.DimStore AS S
        ON F.StoreKey = S.StoreKey
    INNER JOIN dbo.DimChannel AS CH
        ON F.channelKey = CH.ChannelKey
    GROUP BY CH.ChannelName, S.StoreKey, S.StoreName, S.Status
),
RankingPorCanal AS (
    SELECT
        Canal,
        StoreKey,
        Loja,
        StatusLoja,
        VendasTotais,
        LucroComercial,
        MargemComercialPct,
        ROW_NUMBER() OVER (
            PARTITION BY Canal
            ORDER BY VendasTotais DESC, StoreKey ASC
        ) AS PosicaoNoCanal
    FROM VendasPorLojaCanal
)
SELECT
    Canal,
    PosicaoNoCanal,
    StoreKey,
    Loja,
    StatusLoja,
    VendasTotais,
    LucroComercial,
    MargemComercialPct
FROM RankingPorCanal
WHERE PosicaoNoCanal <= 3
ORDER BY Canal, PosicaoNoCanal;

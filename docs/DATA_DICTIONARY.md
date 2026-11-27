# Dicionário de Dados — Contoso Business Intelligence V2

Este documento descreve a estrutura, granularidade, tipos de dados, relacionamentos, regras de negócio e achados de qualidade de dados das tabelas utilizadas no projeto **Contoso Business Intelligence V2**, com base na auditoria direta da cópia local do banco `ContosoRetailDW` em SQL Server.

---

## 1. Visão Geral das Tabelas do Projeto

| Tabela no Banco (`dbo`) | Papel no Modelo Estrela (Power BI) | Volumetria Verificada | Chave Primária | Granularidade |
| --- | --- | ---: | --- | --- |
| `dbo.FactSales` | `FactSales` (Tabela Fato) | 3.406.089 linhas | `SalesKey` | 1 linha por combinação única de data, canal, loja, produto, promoção e moeda |
| `dbo.DimProduct` | `DimProduct` (Dimensão desnormalizada) | 2.517 linhas | `ProductKey` | 1 linha por SKU (produto) |
| `dbo.DimProductSubcategory` | Incorporada em `DimProduct` via Power Query | 44 linhas | `ProductSubcategoryKey` | 1 linha por subcategoria |
| `dbo.DimProductCategory` | Incorporada em `DimProduct` via Power Query | 8 linhas | `ProductCategoryKey` | 1 linha por categoria |
| `dbo.DimStore` | `DimStore` (Dimensão) | 306 linhas | `StoreKey` | 1 linha por unidade comercial (loja física ou canal centralizado) |
| `dbo.DimDate` | `DimDate` (Dimensão Calendário — filtrada 2007–2009) | 2.556 linhas no SQL (1.096 no Power BI) | `Datekey` | 1 linha por dia corrido |
| `dbo.DimChannel` | `DimChannel` (Dimensão) | 4 linhas | `ChannelKey` | 1 linha por canal de vendas |
| `dbo.DimCurrency` | Referência de auditoria de moeda | 28 linhas | `CurrencyKey` | 1 linha por moeda (100% da `FactSales` usa `CurrencyKey = 1` — `USD`) |

> **Observação sobre preservação da V1:** As consultas originais `sql/09_top_clientes_online.sql` (V1) também consultam `dbo.FactOnlineSales` e `dbo.DimCustomer`. O modelo de BI da V2 foca exclusivamente no núcleo comercial da `dbo.FactSales` e nas quatro dimensões do esquema estrela (`DimProduct`, `DimStore`, `DimDate` e `DimChannel`).

---

## 2. Detalhamento por Tabela

### 2.1 `dbo.FactSales` (Tabela Fato)

| Coluna | Tipo SQL Server | Nulo? | Uso no Projeto V2 | Descrição e Regra de Negócio |
| --- | --- | --- | --- | --- |
| `SalesKey` | `int` | Não | Chave primária / validação | Identificador único do registro de venda (0 duplicatas em 3.406.089 linhas). |
| `DateKey` | `datetime` | Não | Chave estrangeira -> `DimDate` | Data da venda. Na `FactSales` cobre de `2007-01-01` a `2009-12-31` (1.096 dias consecutivos). Convertida para `date` no Power Query. |
| `channelKey` | `int` | Não | Chave estrangeira -> `DimChannel` | Identificador do canal de venda (1 = Store, 2 = Online, 3 = Catalog, 4 = Reseller). Renomeada para `ChannelKey` no Power BI. |
| `StoreKey` | `int` | Não | Chave estrangeira -> `DimStore` | Identificador da loja/unidade comercial (306 unidades distintas com vendas). |
| `ProductKey` | `int` | Não | Chave estrangeira -> `DimProduct` | Identificador do produto vendido (2.516 dos 2.517 produtos do catálogo têm vendas). |
| `PromotionKey` | `int` | Não | Auditoria de granularidade | Identificador da promoção aplicada. Compõe a chave natural de granularidade da fato. |
| `CurrencyKey` | `int` | Não | Auditoria de moeda | Identificador da moeda. Verificado: 100% das 3.406.089 linhas possuem `CurrencyKey = 1` (`USD`). |
| `UnitCost` | `money` | Não | Auditoria financeira | Custo unitário registrado na linha de venda. |
| `UnitPrice` | `money` | Não | Auditoria financeira | Preço unitário bruto antes do desconto. |
| `SalesQuantity` | `int` | Não | KPI `Unidades Vendidas` | Quantidade de unidades vendidas (sempre `> 0`; total verificado: `53.320.454`). |
| `ReturnQuantity` | `int` | Não | Auditoria / contexto V1 | Quantidade de unidades devolvidas (480.943 linhas com `ReturnQuantity > 0`). |
| `ReturnAmount` | `money` | Sim | Auditoria / contexto V1 | Valor monetário das devoluções (não é subtraído automaticamente de `SalesAmount`). |
| `DiscountQuantity` | `int` | Sim | Auditoria financeira | Quantidade de unidades com desconto aplicado. |
| `DiscountAmount` | `money` | Sim | Auditoria financeira | Valor do desconto concedido (1.793.112 linhas com `DiscountAmount > 0`). |
| `TotalCost` | `money` | Não | KPI `Custo Total` | Custo comercial total registrado para a linha (sempre `> 0`; total verificado: `USD 5.364.896.601,78`). |
| `SalesAmount` | `money` | Não | KPI `Vendas Totais` | Receita comercial registrada (sempre `> 0`; total verificado: `USD 12.413.657.608,8876`). Verificado: corresponde exatamente a `(UnitPrice * SalesQuantity) - DiscountAmount` em 100% das linhas. |

---

### 2.2 `dbo.DimProduct` + `dbo.DimProductSubcategory` + `dbo.DimProductCategory`

No SQL Server, a hierarquia de produtos segue um desenho **snowflake** (floco de neve):
`DimProduct (ProductSubcategoryKey)` -> `DimProductSubcategory (ProductCategoryKey)` -> `DimProductCategory`.

No Power BI, essas três tabelas são **desnormalizadas no Power Query** (via Mesclar Consultas / `Table.NestedJoin` + `Table.ExpandTableColumn`), produzindo uma única dimensão `DimProduct` em modelo estrela puro com cardinalidade 1:1 validada (`2.517` produtos antes e depois do JOIN; `0` órfãos).

| Coluna (no modelo estrela `DimProduct`) | Origem SQL Server | Tipo | Nulo? | Descrição |
| --- | --- | --- | --- | --- |
| `ProductKey` | `DimProduct.ProductKey` | `int` | Não | Chave primária (2.517 produtos distintos). |
| `ProductName` | `DimProduct.ProductName` | `nvarchar` | Não* | Nome comercial do SKU. |
| `BrandName` | `DimProduct.BrandName` | `nvarchar` | Não* | Marca do produto (ex.: Contoso, Proseware, Litware, Fabrikam). |
| `ClassName` | `DimProduct.ClassName` | `nvarchar` | Não* | Classe comercial (`Economy`, `Regular`, `Deluxe`). |
| `ProductSubcategoryName` | `DimProductSubcategory.ProductSubcategoryName` | `nvarchar` | Não | Subcategoria do produto (44 subcategorias). Tratada com `Text.Trim` no Power Query. |
| `ProductCategoryName` | `DimProductCategory.ProductCategoryName` | `nvarchar` | Não | Categoria principal (8 categorias). Tratada com `Text.Trim` no Power Query. |
| `UnitCost` | `DimProduct.UnitCost` | `money` | Não* | Custo unitário de catálogo. |
| `UnitPrice` | `DimProduct.UnitPrice` | `money` | Não* | Preço unitário de catálogo. |

*\*Colunas definidas como anuláveis no esquema DDL do banco, porém auditadas com **0 valores NULL** em todos os 2.517 registros (`sql/validation/01_integridade_chaves_duplicidade.sql`).*

---

### 2.3 `dbo.DimStore` (Dimensão Loja)

| Coluna | Tipo SQL Server | Nulo? | Descrição e Achados |
| --- | --- | --- | --- |
| `StoreKey` | `int` | Não | Chave primária (306 unidades comerciais). |
| `StoreName` | `nvarchar` | Não | Nome da loja/unidade. |
| `StoreType` | `nvarchar` | Não* | Tipo operacional (`Store`: 299, `Online`: 3, `Reseller`: 3, `Catalog`: 1). |
| `Status` | `nvarchar` | Não | Situação cadastral: `On` (294 lojas) ou `Off` (12 lojas encerradas, que possuem vendas históricas de `USD 272,58 milhões` na `FactSales`). |
| `OpenDate` | `datetime` | Não | Data de inauguração cadastrada. |
| `CloseDate` | `datetime` | Sim | Data de encerramento (294 nulos correspondentes às lojas com `Status = 'On'`). |
| `EmployeeCount` | `int` | Sim | Quantidade de funcionários cadastrada na unidade. |

---

### 2.4 `dbo.DimDate` (Dimensão Calendário)

| Coluna | Origem | Tipo | Descrição |
| --- | --- | --- | --- |
| `DateKey` | `dbo.DimDate.Datekey` | `date` (Power BI) / `datetime` (SQL) | Chave primária diária. No SQL vai de `2005-01-01` a `2011-12-31` (2.556 dias). No Power Query, filtrada para `2007`–`2009` (1.096 dias) para evitar anos vazios nos filtros. |
| `CalendarYear` | `dbo.DimDate.CalendarYear` | `int` | Ano calendário (`2007`, `2008`, `2009`). |
| `CalendarQuarterLabel` | `dbo.DimDate.CalendarQuarterLabel` | `nvarchar` | Trimestre (`Q1`, `Q2`, `Q3`, `Q4`). |
| `AnoMesNumero` | `dbo.DimDate.CalendarMonth` | `int` | Inteiro `YYYYMM` (ex.: `200801`). Usado para ordenar cronologicamente `AnoMes`. |
| `NumeroMes` | Derivada no Power Query (`Date.Month`) | `int` | Número do mês (`1` a `12`). Essencial para ordenar `CalendarMonthLabel` e `MesAbrev` corretamente sem erro de cardinalidade. |
| `CalendarMonthLabel` | `dbo.DimDate.CalendarMonthLabel` | `nvarchar` | Nome do mês em inglês (`January` a `December`), ordenado por `NumeroMes`. |
| `MesAbrev` | Derivada no Power Query (`Date.ToText`) | `text` | Abreviação do mês em português (`jan` a `dez`), ordenada por `NumeroMes`. |
| `AnoMes` | Derivada no Power Query (`yyyy-MM`) | `text` | Rótulo mensal cronológico (`2007-01` a `2009-12`), ordenado por `AnoMesNumero`. |

---

### 2.5 `dbo.DimChannel` (Dimensão Canal)

| Coluna | Tipo SQL Server | Nulo? | Descrição |
| --- | --- | --- | --- |
| `ChannelKey` | `int` | Não | Chave primária (`1` a `4`). |
| `ChannelName` | `nvarchar` | Não* | Nome oficial do canal: `Store`, `Online`, `Catalog` e `Reseller`. |
| `ChannelDescription` | `nvarchar` | Não* | Descrição textual do canal. |

---

## 3. Glossário de Indicadores Financeiros e Regras de Cálculo

| Indicador | Fórmula SQL Server | Fórmula DAX (Power BI) | Regra de Negócio e Interpretação |
| --- | --- | --- | --- |
| **Vendas Totais** | `SUM(SalesAmount)` | `SUM(FactSales[SalesAmount])` | Receita comercial faturada, líquida de descontos (`DiscountAmount`), em `USD`. |
| **Custo Total** | `SUM(TotalCost)` | `SUM(FactSales[TotalCost])` | Custo total de mercadoria registrado nas linhas da `FactSales`, em `USD`. |
| **Unidades Vendidas** | `SUM(SalesQuantity)` | `SUM(FactSales[SalesQuantity])` | Volume físico total de itens comercializados. |
| **Lucro Comercial** | `SUM(SalesAmount) - SUM(TotalCost)` | `[Vendas Totais] - [Custo Total]` | Margem de contribuição bruta comercial (não desconta devoluções, impostos nem despesas operacionais). |
| **Margem Comercial** | `CAST((SUM(SalesAmount) - SUM(TotalCost)) AS DECIMAL(18,6)) / NULLIF(SUM(SalesAmount), 0)` | `DIVIDE([Lucro Comercial], [Vendas Totais])` | **Margem ponderada real.** Deve ser sempre calculada como razão dos totais, jamais como média simples das margens individuais. |
| **Receita por Unidade** | `CAST(SUM(SalesAmount) AS DECIMAL(18,6)) / NULLIF(SUM(SalesQuantity), 0)` | `DIVIDE([Vendas Totais], [Unidades Vendidas])` | Preço líquido médio realizado por unidade vendida. |
| **Custo por Unidade** | `CAST(SUM(TotalCost) AS DECIMAL(18,6)) / NULLIF(SUM(SalesQuantity), 0)` | `DIVIDE([Custo Total], [Unidades Vendidas])` | Custo médio realizado por unidade vendida. |
| **Lucro por Unidade** | `CAST((SUM(SalesAmount) - SUM(TotalCost)) AS DECIMAL(18,6)) / NULLIF(SUM(SalesQuantity), 0)` | `DIVIDE([Lucro Comercial], [Unidades Vendidas])` | Lucro comercial médio obtido por unidade vendida. |

---

## 4. Achados Reais de Qualidade de Dados (Auditoria ContosoRetailDW)

Os itens abaixo foram verificados diretamente no SQL Server e orientaram decisões concretas de modelagem e análise:

1. **Espaços em branco à direita em textos categóricos:** `DimProductCategory.ProductCategoryName` possui o valor `'Cameras and camcorders '` (com espaço ao final) e `DimProductSubcategory.ProductSubcategoryName` possui `'Smart phones & PDAs '` (com espaço ao final). Ambos são higienizados com `Text.Trim` no Power Query.
2. **Espaço duplo em nomes de lojas:** Algumas lojas em `DimStore` possuem espaço duplo interno (ex.: `Contoso Sydney  No.2 Store`, `Contoso Taipei  Store`, `Contoso Moscow  No.2 Store`). Mantido no SQL para fidelidade à chave textual original e documentado para evitar falhas em buscas exatas.
3. **Armadilha de ordenação em `DimDate.CalendarMonth`:** A coluna `CalendarMonth` da base original armazena inteiros `YYYYMM` (ex.: `200801`), e não `1..12`. Tentar ordenar `CalendarMonthLabel` por `CalendarMonth` no Power BI gera erro de duplicidade de chave de ordenação. Solução: criação da coluna `NumeroMes` (`1..12`) no Power Query.
4. **Cobertura de datas da `DimDate` maior que `FactSales`:** `DimDate` cobre 2005–2011, enquanto `FactSales` cobre 2007–2009. O filtro para 2007–2009 no Power Query evita anos sem movimento nos segmentadores.
5. **Produto sem venda na `FactSales`:** Apenas 1 produto do catálogo (`ProductKey = 944`, `A. Datum Compact Digital Camera M200 Black`) não possui registros na `FactSales`.
6. **Lojas encerradas (`Status = 'Off'`) com receita histórica:** As 12 lojas encerradas acumulam `USD 272.575.025,98` em vendas na `FactSales`. Filtrar apenas lojas `On` reduziria indevidamente o histórico da empresa.
7. **Inconsistência temporal sintética em `OpenDate` de lojas recentes:** Na base demonstrativa da Microsoft, lojas como `Contoso Venezia Store` (`OpenDate = 2009-07-06`) registram vendas distribuídas por 12 meses de calendário (`MesesComVenda = 12`), evidenciando geração sintética de datas na base de treinamento.
8. **Composição de `TotalCost`:** Enquanto `SalesAmount` bate 100% com `(UnitPrice * SalesQuantity) - DiscountAmount` (`0` divergências em 3.406.089 linhas), `TotalCost` não segue uma fórmula única fechada em todas as linhas (`319.080` linhas divergem de `UnitCost * SalesQuantity` e `166.830` divergem de `UnitCost * (SalesQuantity - ReturnQuantity)`). Por isso, todas as consultas e medidas utilizam a coluna oficial `TotalCost`.

# Relatório de Validação e Reconciliação — SQL Server vs. Power BI (DAX)

Este relatório documenta as verificações efetivamente executadas sobre o banco local **ContosoRetailDW** (SQL Server) e sobre o motor Tabular/VertiPaq real do **Power BI Desktop** (`msmdsrv.exe`, consultado via ADOMD.NET após atualização completa das 5 tabelas via Power Query M).

> **Princípio de integridade:** Todos os números abaixo foram obtidos por execução real das consultas em [`sql/validation/`](../sql/validation/), [`sql/kpis/`](../sql/kpis/) e das medidas DAX em [`powerbi/measures.dax`](../powerbi/measures.dax) no modelo [`powerbi/Contoso_BI_V2/`](../powerbi/Contoso_BI_V2/). Nenhuma métrica foi estimada ou simulada.

---

## 1. Resumo das Auditorias de Qualidade e Modelagem (SQL Server)

| Verificação | Script Executado | Resultado Verificado | Status |
| --- | --- | --- | --- |
| Unicidade de chaves primárias (7 tabelas) | `sql/validation/01_integridade_chaves_duplicidade.sql` | 0 duplicatas (`FactSales`: 3.406.089; `DimProduct`: 2.517; `DimStore`: 306; `DimDate`: 2.556; `DimChannel`: 4; `DimProductSubcategory`: 44; `DimProductCategory`: 8) | Aprovado |
| Granularidade composta da `FactSales` | `sql/validation/01_integridade_chaves_duplicidade.sql` | 0 duplicatas na combinação `(DateKey, channelKey, StoreKey, ProductKey, PromotionKey, CurrencyKey)` | Aprovado |
| Valores ausentes (`NULL`) em chaves e métricas | `sql/validation/01_integridade_chaves_duplicidade.sql` | 0 nulos na `FactSales` e na `DimProduct`; na `DimStore`, 294 nulos apenas em `CloseDate` (lojas com `Status = 'On'`) | Aprovado |
| Integridade referencial (chaves órfãs) | `sql/validation/02_cardinalidade_joins_granularidade.sql` | 0 órfãos para Produto, Loja, Canal e Data | Aprovado |
| Desnormalização 1:1 da `DimProduct` | `sql/validation/02_cardinalidade_joins_granularidade.sql` | 2.517 produtos antes e depois dos JOINs com subcategoria e categoria (0 sem categoria) | Aprovado |
| Teste anti-fan-out (antes vs. depois dos JOINs) | `sql/validation/02_cardinalidade_joins_granularidade.sql` | Diferença exatamente `0` em linhas, `0,0000` em Vendas, `0,0000` em Custo e `0` em Unidades | Aprovado |
| Uniformidade de moeda | `sql/validation/02_cardinalidade_joins_granularidade.sql` | 100% dos 3.406.089 registros em `USD` (`CurrencyKey = 1`) | Aprovado |
| Sanidade de sinais e divisão por zero | `sql/validation/03_validacao_calculos_financeiros.sql` | 0 registros com vendas, custo ou quantidade `<= 0`; 0 linhas com prejuízo bruto; todas as divisões protegidas por `NULLIF` (SQL) e `DIVIDE` (DAX) | Aprovado |
| Regra de Margem Ponderada vs. Média Simples | `sql/validation/03_validacao_calculos_financeiros.sql` | Margem ponderada correta = **56,7823%**; média simples por linha = 53,3095% (distorção de `-3,4728 p.p.`); média simples por produto = 54,2414% (`-2,5409 p.p.`) | Aprovado |

---

## 2. Reconciliação de Carga de Tabelas (SQL Server vs. Power BI VertiPaq)

| Tabela no Power BI | Linhas no SQL Server | Linhas Carregadas no Power BI | Diferença | Observação |
| --- | ---: | ---: | ---: | --- |
| `FactSales` | 3.406.089 | 3.406.089 | 0 | Carga integral (colunas selecionadas para otimização) |
| `DimProduct` | 2.517 | 2.517 | 0 | Desnormalizada no Power Query com categoria e subcategoria + `Text.Trim` |
| `DimStore` | 306 | 306 | 0 | Carga integral (294 `On` + 12 `Off`) |
| `DimDate` | 2.556 (2005–2011) | 1.096 (2007–2009) | 0 no período fato | Filtrada no Power Query para o período exato da `FactSales` (2007–2009) |
| `DimChannel` | 4 | 4 | 0 | Carga integral (`Store`, `Online`, `Catalog`, `Reseller`) |

---

## 3. Reconciliação Numérica Independente: SQL Server vs. DAX (Power BI)

Cada bloco abaixo confronta a consulta SQL independente (`sql/kpis/02_matriz_reconciliacao_powerbi.sql` e `sql/commercial_analysis/`) com a execução direta das medidas DAX (`[Vendas Totais]`, `[Custo Total]`, `[Unidades Vendidas]`, `[Lucro Comercial]`, `[Margem Comercial]`) no motor do Power BI Desktop.

### 3.1 Controle 1 — Total Geral (Sem Filtros)

| Métrica | SQL Server (`ContosoRetailDW`) | Power BI (DAX ao vivo) | Diferença | Status |
| --- | ---: | ---: | ---: | --- |
| **Vendas Totais (USD)** | 12.413.657.608,8876 | 12.413.657.608,8876 | 0,0000 | Exato |
| **Custo Total (USD)** | 5.364.896.601,7800 | 5.364.896.601,7800 | 0,0000 | Exato |
| **Unidades Vendidas** | 53.320.454 | 53.320.454 | 0 | Exato |
| **Lucro Comercial (USD)** | 7.048.761.007,1076 | 7.048.761.007,1076 | 0,0000 | Exato |
| **Margem Comercial** | 0,567823 (56,78%) | 0,567823 (56,78%) | 0,000000 | Exato |
| **Receita por Unidade (USD)** | 232,81 | 232,8123 | 0,00 | Exato |

---

### 3.2 Controle 2 — Propagação de Filtro por Ano (`DimDate` -> `FactSales`)

| Ano | Vendas Totais (SQL = DAX) | Custo Total (SQL = DAX) | Unidades (SQL = DAX) | Lucro Comercial (SQL = DAX) | Margem (SQL = DAX) | Diferença |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| **2007** | 4.561.940.955,0212 | 1.966.906.968,81 | 16.984.310 | 2.595.033.986,2112 | 56,8844% | 0 |
| **2008** | 4.111.233.534,6841 | 1.773.348.839,62 | 16.511.811 | 2.337.884.695,0641 | 56,8658% | 0 |
| **2009** | 3.740.483.119,1823 | 1.624.640.793,35 | 19.824.333 | 2.115.842.325,8323 | 56,5660% | 0 |

---

### 3.3 Controle 3 — Propagação de Filtro por Canal (`DimChannel` -> `FactSales`)

| Canal | Vendas Totais (SQL = DAX) | Custo Total (SQL = DAX) | Unidades (SQL = DAX) | Lucro Comercial (SQL = DAX) | Margem (SQL = DAX) | Diferença |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| **Store** | 6.942.853.195,1440 | 2.992.579.668,63 | 29.089.448 | 3.950.273.526,5140 | 56,8970% | 0 |
| **Online** | 2.677.599.035,0748 | 1.163.294.363,13 | 12.506.063 | 1.514.304.671,9448 | 56,5546% | 0 |
| **Reseller** | 1.715.197.831,4421 | 743.558.867,34 | 7.270.570 | 971.638.964,1021 | 56,6488% | 0 |
| **Catalog** | 1.078.007.547,2267 | 465.463.702,68 | 4.454.373 | 612.543.844,5467 | 56,8219% | 0 |

---

### 3.4 Controle 4 — Propagação de Filtro por Categoria (`DimProduct` Desnormalizada -> `FactSales`)

| Categoria (higienizada no Power Query) | Vendas Totais (SQL = DAX) | Custo Total (SQL = DAX) | Unidades (SQL = DAX) | Lucro Comercial (SQL = DAX) | Margem (SQL = DAX) | Diferença |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| **Home Appliances** | 3.922.736.787,1910 | 1.743.252.182,23 | 10.379.472 | 2.179.484.604,9610 | 55,5603% | 0 |
| **Computers** | 3.209.427.141,4172 | 1.384.267.233,46 | 10.563.676 | 1.825.159.907,9572 | 56,8687% | 0 |
| **Cameras and camcorders** | 2.562.023.774,0606 | 1.025.068.564,31 | 6.551.189 | 1.536.955.209,7506 | 59,9899% | 0 |
| **TV and Video** | 1.360.121.114,7642 | 617.685.065,43 | 3.449.196 | 742.436.049,3342 | 54,5860% | 0 |
| **Cell phones** | 892.233.264,2984 | 395.577.197,17 | 13.459.636 | 496.656.067,1284 | 55,6644% | 0 |
| **Music, Movies and Audio Books** | 165.804.705,9811 | 64.933.881,71 | 1.523.415 | 100.870.824,2711 | 60,8371% | 0 |
| **Audio** | 151.614.364,3109 | 64.875.538,31 | 1.353.298 | 86.738.826,0009 | 57,2102% | 0 |
| **Games and Toys** | 149.696.456,8642 | 69.236.939,16 | 6.040.572 | 80.459.517,7042 | 53,7484% | 0 |

---

### 3.5 Controles 5 e 6 — Propagação Simultânea Multidimensional (2D e 3D)

| Recorte Combinado | Vendas Totais (SQL = DAX) | Custo Total (SQL = DAX) | Unidades (SQL = DAX) | Lucro Comercial (SQL = DAX) | Margem (SQL = DAX) | Diferença |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| **2008 + Online** | 937.069.110,9298 | 406.631.362,16 | 3.942.776 | 530.437.748,7698 | 56,6060% | 0 |
| **2009 + Store + Computers** | 617.083.601,3369 | 267.484.833,96 | 2.099.168 | 349.598.767,3769 | 56,6534% | 0 |

---

### 3.6 Controles 7, 8 e 9 — Propagação `DimStore` e `DimProduct` (Rankings Top/Bottom)

- **Top 5 Lojas (SQL = DAX):** `Contoso Catalog Store` (1.078.007.547,2267), `Contoso North America Online Store` (984.249.404,2534), `Contoso Asia Online Store` (887.049.174,4335), `Contoso Europe Online Store` (806.300.456,3879), `Contoso North America Reseller` (628.168.708,5233) — **diferença 0**.
- **Bottom 5 Lojas (SQL = DAX):** `Contoso Venezia Store` (1.773.000,1830), `Contoso Racine No.2 Store` (2.641.604,4720), `Contoso Kyoto Store` (4.694.285,3605), `Contoso Berlin Store` (5.084.164,1215), `Contoso Dallas Store` (5.492.546,0200) — **diferença 0**.
- **Top 5 Produtos (SQL = DAX):** `Proseware Projector 1080p DLP86 White` (51.901.056,27), `Proseware Projector 1080p DLP86 Silver` (51.484.223,07), `Proseware Projector 1080p DLP86 Black` (49.266.460,53), `Proseware Projector 1080p LCD86 White` (47.504.870,55), `Contoso Projector 1080p X980 White` (47.499.546,15) — **diferença 0**.

---

## 4. Conclusão da Reconciliação

Os nove controles independentes confirmaram **100% de aderência numérica** entre o banco `ContosoRetailDW` no SQL Server e o modelo estrela no Power BI Desktop:
- Relacionamentos 1:N unidirecionais propagam filtros corretamente em todas as quatro dimensões (`DimDate`, `DimChannel`, `DimProduct` e `DimStore`), isoladamente e em combinação.
- Não há perda de registros, duplicação por fan-out ou erro de agregação de margem.

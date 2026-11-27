# Especificação Visual e Guia de Construção do Dashboard — Contoso BI V2

Este documento especifica a identidade visual, a estrutura das **3 páginas executivas**, os filtros, os cartões de KPI e o passo a passo completo para reconstruir ou personalizar o dashboard comercial **Contoso Business Intelligence V2** no **Power BI Desktop**.

O projeto Power BI real já construído e validado sobre o `ContosoRetailDW` está disponível em [`powerbi/Contoso_BI_V2/Contoso_BI_V2.pbip`](Contoso_BI_V2/Contoso_BI_V2.pbip), com capturas reais das páginas e do modelo estrela em [`reports/`](../reports/).

---

## 1. Identidade Visual e Padrões de Layout

| Elemento | Especificação |
| --- | --- |
| **Dimensão da Tela (Canvas)** | `1280 × 720 px` (proporção 16:9 padrão executivo) |
| **Fundo da Página** | Cinza-azulado claro `#F4F6F9` (0% transparência) |
| **Cabeçalho Superior** | Faixa azul-marinho `#0F2942` (`1280 × 82 px`) com título em branco `#FFFFFF` (`Segoe UI Semibold 17pt`) e subtítulo `#CBD5E1` (`9.5pt`) |
| **Contêineres / Cartões** | Fundo `#FFFFFF`, borda `#E2E8F0` (`radius: 8px`), sombra suave `#CBD5E1` (transparência `70%`) |
| **Paleta Semântica Consistente** | **Azul-Marinho `#0F2942`** (Vendas Totais / série principal) · **Verde-Petróleo `#0D9488`** (Lucro Comercial / Top performers) · **Âmbar `#D97706`** (Margem Comercial %) · **Cinza-Ardósia `#475569`** (Custo Total) · **Azul Royal `#1D4ED8`** (Unidades / Receita Unitária) · **Vermelho Coral `#DC2626`** (Alertas / Bottom 10) |
| **Tipografia** | Família `Segoe UI` / `Segoe UI Semibold` / `Segoe UI Bold` |
| **Regra de Consistência** | Todas as páginas exibem barra superior padronizada com 3 segmentadores suspensos (`Dropdown`), fileira de KPIs de topo e duas linhas balanceadas de gráficos/tabelas, sem sobrecarga visual |

---

## 2. Detalhamento das Três Páginas do Relatório

### Página 1 — `Visão Executiva`

**Objetivo empresarial:** Entregar em segundos a saúde comercial consolidada da Contoso (faturamento, custos, lucro, margem ponderada e volume), a trajetória mensal contínua (2007–2009), o peso dos canais e categorias e o resumo anual reconciliável com o SQL Server.

| Bloco | Tipo de Visual | Campos / Medidas | Configuração Chave |
| --- | --- | --- | --- |
| **Filtros Globais (Cabeçalho)** | 3 Segmentadores (`Dropdown`) | `DimDate[CalendarYear]`, `DimChannel[ChannelName]`, `DimProduct[ProductCategoryName]` | Estilo suspenso compacto no cabeçalho `#1E3A5F` |
| **KPI 1** | Cartão (`Card`) | `[Vendas Totais]` | Cor `#0F2942`, valor sem filtro: `US$ 12,41 Bi` |
| **KPI 2** | Cartão (`Card`) | `[Custo Total]` | Cor `#475569`, valor sem filtro: `US$ 5,36 Bi` |
| **KPI 3** | Cartão (`Card`) | `[Lucro Comercial]` | Cor `#0D9488`, valor sem filtro: `US$ 7,05 Bi` |
| **KPI 4** | Cartão (`Card`) | `[Margem Comercial]` | Cor `#D97706`, valor sem filtro: `56,78%` |
| **KPI 5** | Cartão (`Card`) | `[Unidades Vendidas]` | Cor `#1D4ED8`, valor sem filtro: `53 Mi` (`53.320.454`) |
| **Evolução Mensal (Esquerda Sup.)** | Gráfico de Linhas (`Line Chart`) | Eixo X: `DimDate[InicioMes]` (contínuo) · Eixo Y: `[Vendas Totais]`, `[Lucro Comercial]` | Legenda no topo; mostra todos os 36 meses (2007–2009) sem barra de rolagem horizontal |
| **Vendas por Canal (Direita Sup.)** | Gráfico de Barras Clusterizadas | Eixo Y: `DimChannel[ChannelName]` · Eixo X: `[Vendas Totais]` | Ordenado por `[Vendas Totais]` DESC, rótulos de dados ativados |
| **Vendas e Lucro por Categoria (Esquerda Inf.)** | Gráfico de Barras Clusterizadas | Eixo Y: `DimProduct[ProductCategoryName]` · Eixo X: `[Vendas Totais]`, `[Lucro Comercial]` | Ordenado por `[Vendas Totais]` DESC, todas as 8 categorias visíveis |
| **Consolidado Anual (Direita Inf.)** | Tabela (`Table`) | `DimDate[CalendarYear]`, `[Vendas Totais]`, `[Lucro Comercial]`, `[Margem Comercial]`, `[Unidades Vendidas]`, `[Receita por Unidade]` | Permite conferência direta com `sql/kpis/01_kpis_executivos_gerais.sql` e evidencia a queda de receita/unidade em 2009 |

---

### Página 2 — `Produtos e Categorias`

**Objetivo empresarial:** Avaliar rentabilidade real por categoria (sem a armadilha da média simples), identificar os **Top 10** e **Bottom 10** produtos vendidos e detalhar a contribuição das 44 subcategorias.

| Bloco | Tipo de Visual | Campos / Medidas | Filtros e Ordenação |
| --- | --- | --- | --- |
| **Filtros (Cabeçalho)** | 3 Segmentadores (`Dropdown`) | `DimDate[CalendarYear]`, `DimProduct[ProductCategoryName]`, `DimProduct[BrandName]` | Propagação 1:N unidirecional para `FactSales` |
| **Fileira de KPIs** | 4 Cartões (`Card`) | `[Vendas Totais]`, `[Lucro Comercial]`, `[Margem Comercial]`, `[Receita por Unidade]` | Atualizados dinamicamente por categoria/marca/ano |
| **Margem Comercial por Categoria (Esquerda Sup.)** | Gráfico de Barras Clusterizadas | Eixo Y: `DimProduct[ProductCategoryName]` · Eixo X: `[Margem Comercial]` | Ordenado por `[Margem Comercial]` DESC, rótulos em `%` ativados, cor `#D97706` |
| **Top 10 Produtos (Direita Sup.)** | Gráfico de Barras Clusterizadas | Eixo Y: `DimProduct[ProductName]` · Eixo X: `[Vendas Totais]` | **Filtro de nível visual Top N = Superior 10** por `[Vendas Totais]`, cor `#0D9488`, rótulos ativados |
| **Bottom 10 Produtos Vendidos (Esquerda Inf.)** | Tabela (`Table`) | `DimProduct[ProductName]`, `[Vendas Totais]`, `[Unidades Vendidas]`, `[Margem Comercial]` | **Filtro de nível visual Top N = Inferior 10** por `[Vendas Totais]` (apenas produtos com vendas `> 0`), título em `#DC2626` |
| **Detalhamento Categoria e Subcategoria (Direita Inf.)** | Tabela (`Table`) | `DimProduct[ProductCategoryName]`, `DimProduct[ProductSubcategoryName]`, `[Vendas Totais]`, `[Lucro Comercial]`, `[Margem Comercial]` | Ordenado por `[Vendas Totais]` DESC |

---

### Página 3 — `Lojas, Canais e Períodos`

**Objetivo empresarial:** Comparar a sazonalidade mensal entre 2007, 2008 e 2009, consolidar a eficiência dos 4 canais e destacar as **Top 10** e **Bottom 10** lojas (permitindo isolar lojas físicas `Store` ou status `On`/`Off`).

| Bloco | Tipo de Visual | Campos / Medidas | Filtros e Ordenação |
| --- | --- | --- | --- |
| **Filtros (Cabeçalho)** | 3 Segmentadores (`Dropdown`) | `DimDate[CalendarYear]`, `DimChannel[ChannelName]`, `DimStore[Status]` | Permite isolar o canal `Store` para comparar lojas físicas sem distorção dos centros regionais Online/Catalog/Reseller |
| **Fileira de KPIs** | 4 Cartões (`Card`) | `[Vendas Totais]`, `[Custo Total]`, `[Lucro Comercial]`, `[Margem Comercial]` | Refletem instantaneamente o filtro de canal e status |
| **Sazonalidade Mensal por Ano (Esquerda Sup.)** | Gráfico de Linhas (`Line Chart`) | Eixo X: `DimDate[MesAbrev]` (ordenado por `NumeroMes`) · Legenda: `DimDate[CalendarYear]` · Eixo Y: `[Vendas Totais]` | Evidencia Q1 mais fraco (jan–mar) e picos em mai, nov e dez nos três anos |
| **Top 10 Lojas (Direita Sup.)** | Gráfico de Barras Clusterizadas | Eixo Y: `DimStore[StoreName]` · Eixo X: `[Vendas Totais]` | **Filtro de nível visual Top N = Superior 10** por `[Vendas Totais]`, rótulos ativados |
| **Consolidado por Canal (Esquerda Inf.)** | Tabela (`Table`) | `DimChannel[ChannelName]`, `[Vendas Totais]`, `[Lucro Comercial]`, `[Margem Comercial]`, `[Unidades Vendidas]`, `[Receita por Unidade]` | Ordenado por `[Vendas Totais]` DESC |
| **Bottom 10 Lojas (Direita Inf.)** | Tabela (`Table`) | `DimStore[StoreName]`, `DimStore[Status]`, `[Vendas Totais]`, `[Lucro Comercial]`, `[Margem Comercial]` | **Filtro de nível visual Top N = Inferior 10** por `[Vendas Totais]` (vendas `> 0`), ordenado ASC |

---

## 3. Como Abrir ou Reconstruir o Relatório no Power BI Desktop

### Caminho A — Abrir o projeto pronto (`.pbip`)
1. Certifique-se de que o banco `ContosoRetailDW` está restaurado na instância local do SQL Server (`localhost`).
2. Abra o **Power BI Desktop** -> **Arquivo** -> **Abrir relatório** -> selecione [`powerbi/Contoso_BI_V2/Contoso_BI_V2.pbip`](Contoso_BI_V2/Contoso_BI_V2.pbip).
3. Na guia **Página Inicial**, clique em **Atualizar** para carregar os dados do SQL Server local (3.406.089 linhas na `FactSales`).
4. Opcionalmente, salve uma cópia local em `.pbix` via **Arquivo -> Salvar como**.

### Caminho B — Reconstruir manualmente passo a passo (para estudo prático)
1. Conecte-se a `localhost` / `ContosoRetailDW` (modo **Importar**) seguindo o roteiro do Power Query em [`powerbi/model_documentation.md`](model_documentation.md).
2. Configure os 4 relacionamentos `1:N` unidirecionais (`DimDate`, `DimProduct`, `DimStore`, `DimChannel` -> `FactSales`) e a classificação de `MesAbrev`/`CalendarMonthLabel` por `NumeroMes` e `AnoMes` por `AnoMesNumero`.
3. Crie as 8 medidas DAX de [`powerbi/measures.dax`](measures.dax) e oculte as colunas brutas da `FactSales`.
4. Monte as 3 páginas seguindo a tabela de visuais e a paleta da Seção 1 e Seção 2.
5. Teste os 6 cenários de controle de [`sql/kpis/02_matriz_reconciliacao_powerbi.sql`](../sql/kpis/02_matriz_reconciliacao_powerbi.sql) nos filtros do relatório para confirmar divergência zero.

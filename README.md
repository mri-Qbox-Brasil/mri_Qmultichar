# mri_Qmultichar

Multichar externo para Qbox Framework com NUI moderna baseada em shadcn/ui, React e Vite.

## Características

- ✨ Interface moderna e responsiva com mri/ui kit
- 🎨 Design elegante com gradientes e animações
- 📦 Sistema de slots personalizáveis via comando e banco de dados
- 🔄 Integração completa com qbx_core
- 🎭 Preview de personagens com câmera
- ⚡ Performance otimizada com Vite

## Instalação

1. Coloque a pasta `mri_Qmultichar` na sua pasta `resources`


2. Configure o `qbx_core` para usar multichar externo:
   ```lua
   -- Em qbx_core/config/client.lua
   characters = {
       useExternalCharacters = true, -- Ativar multichar externo
   }
   ```

3. Adicione ao seu `server.cfg`:
   ```
   ensure mri_Qmultichar
   ```

## Comandos

### `/setslots [id] [slots]`
Define o número de slots de personagem de um jogador.
- **Permissão**: Admin
- **Parâmetros**:
  - `id`: ID do jogador
  - `slots`: Número de slots (1-10)

**Exemplo:**
```
/setslots 1 5
```

### `/getslots [id]`
Verifica o número de slots de personagem de um jogador.
- **Permissão**: Admin
- **Parâmetros**:
  - `id`: ID do jogador

**Exemplo:**
```
/getslots 1
```

## Configuração

Slots (padrão e máximo), tela inicial, música e posições do showroom se ajustam no
`/adminchar` e ficam em `data/config.json`.

## Música de fundo

Troca-se pelo `/adminchar`, aba **Tela inicial**: ligar/desligar, link (YouTube ou arquivo em
`sounds/`) e volume inicial. Salvar grava em `data/config.json` e atualiza ao vivo quem estiver
na tela.

A trilha segue por toda a criação, em fases: menu (tela inicial e personagens), capítulos da
criação, editor de aparência e cena de chegada. Cada fase pode ter faixa própria, nos campos
logo abaixo do link; a troca é por crossfade e fase vazia segue a faixa da anterior. Ao entrar
no jogo (ou no fim da chegada) a música some aos poucos.

Com o módulo "Trilha sonora" do `mri_Qbox` ligado, as fases viram pedidos pra ele
(chave `music:mri_Qmultichar` no statebag do jogador, prioridade de cena, sem export) e o player próprio fica parado: a música passa
a seguir o slider de efeitos sonoros das configurações de áudio do GTA, abaixa quando o jogador fala e volta ao
que o servidor estava tocando quando a criação termina. A criação continua abaixando a
música pelos efeitos (`duck`); o reforço de volume do final só existe no player próprio.
Os pedidos vão com `display = 'none'` (mri_Qbox v2.1 ou mais nova): a faixa toca sem aviso
nem player na tela do mri_Qbox, que fica por baixo da tela do multichar enquanto ela tem o foco. Sem o `mri_Qbox`, nada muda.

As faixas que vêm configuradas são livres pra usar com crédito: Music by Karl Casey @ White Bat
Audio (https://karlcasey.bandcamp.com). Menu: "L.A. Sunset". Criação: "Echoes". Editor:
"White Gold". Chegada: "Last Stop". História do contêiner: "Containment".

## Showroom

Cada personagem aparece numa posição do palco, com a roupa dele e uma animação.

- A câmera tem um balanço leve de câmera na mão e desfoca o fundo, com foco no
  personagem. Os dois ficam em `Config.Showroom.cam` (`breathe` e `dof`).
- O nome em 3D atrás do personagem se limita a uma fração do quadro
  (`Config.Showroom.nametag.fit`), então nome comprido não sai cortado.
- **Deletar** não abre modal. A confirmação entra na própria barra: segure o anel (mouse
  ou Delete) e o personagem some da cena. Os seguintes andam uma posição, sem remontar o
  showroom. Esc ou Backspace cancela.

## Abertura

Quem conecta não cai direto nos personagens. Quando a loadscreen fecha, entra uma tela
de título: planos lentos pela cidade, com a marca no centro e "Pressione Enter". Depois do
Enter, a câmera desce do alto até o palco do showroom e o menu entra.

- No `/adminchar`, aba **Abertura**:
  - ligar e desligar;
  - "Adicionar plano" abre uma câmera livre no jogo (WASD e mouse, zoom no scroll, Enter
    salva). Cada plano também pode ser refeito, reordenado ou removido;
  - "Testar" toca a abertura salva até Enter ou Backspace.
- Sem planos ou desligada, a entrada vai direto pros personagens, como antes.
- Os 5 planos que vêm configurados foram escolhidos por coordenada e não foram conferidos
  no jogo. Vale refazê-los pelo painel.
- Ritmo, corte, carga de cada plano e o voo até o palco: `Config.Intro`. Plano que não
  carrega no teto avisa no F8 e segue.
- A abertura só toca na conexão. Voltar pros personagens (logout) abre direto neles.

### Hora e clima do menu

Na mesma aba, a hora e o clima ficam fixos pra quem está na abertura, nos personagens ou
na criação. Assim a vitrine não aparece de madrugada ou na chuva. Ao entrar no jogo, ou
quando a criação termina, volta o horário do servidor. Usa o contrato do qb-weathersync
(`qb-weathersync:client:DisableSync`/`EnableSync`), que o Renewed-Weathersync atende; o
clima vai também em `LocalPlayer.state.playerWeather`, que o Renewed repete enquanto a
sincronização está desligada.

## Criação de personagem

A criação é uma sequência em capítulos sobre a cena (gênero, nome, origem e nascimento).
Um ped de preview aparece no palco da 1ª posição do showroom e acompanha o gênero ao vivo.
Cada capítulo tem um plano de câmera próprio, com fundo desfocado, e o ped olha pra câmera,
entra com um gesto ao trocar de gênero e reage a cada capítulo confirmado. Confirmar a data
cria o personagem: o ped faz a pose final, a câmera vai até o plano inicial do editor de
aparência e entra o cartão com o nome. O palco é o estúdio do editor: o ped do jogador toma
o lugar do preview e o editor abre ali mesmo, sem fade nem teleporte, com a luz do palco
acesa até ele fechar.

- Planos, desfoque, olhar, vibração do controle, duração do final e animações:
  `Config.Showroom.creation` (`shots`, `dof`, `lookAtCamera`, `haptics`, `finaleHold`,
  `anims`). Dict de animação que não existir no jogo avisa uma vez no F8 e é ignorado.
- Entrar na criação é uma transição: a tela de personagens sai com fade, os personagens
  do palco somem, a câmera sobe num arco lento até o palco e só então a criação entra.
  Tempos e altura do arco: `Config.Showroom.creation.enter`.
- O ped da criação já vem com rosto, cabelo, sobrancelha e (no masculino) barba curta, e
  o editor de aparência abre a partir desse visual. Cada gênero se ajusta em
  `Config.Showroom.creation.preset` (pais, cabelo, cor dos olhos, overlays e roupas).
- `Config.Showroom.creation.editorCamera` repete o plano e o desfoque com que o editor de
  aparência abre (valores do mri_Qappearance). Com outro appearance, ajuste pra bater.
- Os efeitos sonoros da criação são sintetizados na NUI (`web/src/lib/synth.ts`), sem
  arquivos. A música abaixa durante a criação e sobe no final.
- No capítulo de origem, cada nacionalidade mostra a bandeira (pacote `flag-icons`, MIT,
  empacotado no build) e a cor de destaque do capítulo vem da própria bandeira. Nacionalidades
  e códigos de país ficam em `web/src/data/nationalities.ts`; código novo entra também no
  glob de `web/src/lib/flags.ts`.

## Histórias de chegada

O último capítulo da criação pergunta **"O que te trouxe a Los Santos?"**. As respostas
sugerem a história sem dizer qual é, e a cena revela. Estrangeiro (qualquer nacionalidade
que não "Americano") vê o contêiner primeiro.

**A passagem** (`client/prelude.lua`, `Config.Prelude`), comum a todas as histórias:

1. A câmera do editor de aparência é assumida no mesmo frame em que ele a solta, sem corte.
2. Zoom seco no rosto, com um whoosh.
3. Freeze: o mundo quase para (`SetTimeScale`), a imagem fica em preto e branco
   (`HeistCelebPassBW`), a música corta com um risco de disco e o nome do personagem entra
   batendo, com idade e nacionalidade digitadas embaixo.
4. O cartão do capítulo corta a tela na diagonal ("Capítulo final", título da história,
   lugar e hora). A história monta e carrega embaixo dele.
5. O cartão sai na diagonal oposta e revela o primeiro plano, com as barras de cinema e a
   faixa de chegada da música.

**As histórias**, uma por arquivo em `client/stories/<id>.lua`, narradas por legendas
(locales: `story.<id>_N`):

- **Contêiner do coyote** (`container`): escuro dentro do contêiner, com feixes de luz pelas
  frestas; o guindaste pousa o contêiner; as portas abrem com a luz estourando; o personagem
  sai pro porto. O contêiner é o do trem do DLC Tuners (`tr_prop_tr_container_01a`): as
  portas são do próprio modelo e abrem pela animação `action_container`, a partir do ponto
  `openPhase`. Modelo, lado das portas (`doorAxis`), tempos e câmeras em
  `Config.Arrival.container`. Com o debug ligado, o F8 registra as medidas do modelo e a
  duração da animação (`[CHEGADA] contêiner: ...` e `[CHEGADA] portas: ...`).
  A colisão do modelo não acompanha a animação (as portas continuam fechadas nela): um
  `prop_ld_container` invisível fica no mesmo lugar, e quando as portas abrem o animado perde a
  colisão. A partir daí paredes e piso vêm do `prop_ld_container`, com a entrada livre, e dá
  pra entrar e sair do contêiner depois da cena.
  Som da cena, todo do próprio GTA e tocado do contêiner (`Config.Arrival.container.sounds`):
  no escuro, metal rangendo em loop, rangidos soltos e uma buzina de navio ao longe; no
  impacto, três camadas juntas (o contêiner pousando e uma batida); na abertura, a porta do
  contêiner, o clarão e gaivotas; na saída, a buzina de novo, mais longe. Com o debug ligado, o
  F8 avisa se algum banco de áudio não carregou.
- **Avião** (`plane`): cutscene da abertura do GTA Online (`mp_intro_concat`) com legendas,
  depois o jogador vai pro destino.

No `/adminchar`, aba **Histórias**: ligar/desligar cada uma, marcar o destino com "usar minha
posição" e testar (o teste toca a passagem também). No contêiner, o destino é onde o
personagem pisa ao sair, de costas pra onde o contêiner vai aparecer. Cada história pode ter a
própria **faixa** (link do YouTube, link direto ou `@resource/caminho`, como as da aba Tela
inicial), no lugar da faixa de chegada, da revelação até o fim da cena. Ela segue o mesmo
caminho das outras: com a trilha do mri_Qbox ligada vai por ela, sem ele toca no player do
multichar. Vazio = segue a faixa de chegada. Só aparecem na criação
as ligadas e com destino marcado; nenhuma = sem o capítulo. Enter ou espaço pulam a cena.

**História nova:** um arquivo em `client/stories/<id>.lua` com
`Arrival.stories.<id> = function(ctx, spawn, a) ... end` (`ctx` traz câmeras, legendas,
`reveal`, `hold`, `handBack`), a entrada em `arrivals` no `server/panel.lua` e no
`ArrivalsOffered`, o id em `ARRIVAL_IDS` do painel e os textos no locale (`story.<id>_*` e
a resposta `character_creation.arrival_<id>`).

## Tema

A NUI segue o tema da suíte MRI (`@mriqbox/ui-kit`, guia em `THEMING.md` do pacote) e
muda ao vivo, sem restart:

| O que | De onde vem |
|---|---|
| Cor de destaque | convar `mri:color` (`server/main.lua` propaga a mudança) |
| Cor de fundo | convar `mri:backgroundColor`, vazio = `#09090B` (idem) |
| Tema dark/glass, opacidade, radius, fonte, cores de status e overrides de destaque/fundo | `/uiconfig` do ox_lib (`client/nui.lua` busca no boot e ouve `ox_lib:uiConfigChanged`) |
| Cor pessoal do jogador | painel de configurações da tela, se `Config.AllowAccentOverride`; vence o override do `/uiconfig` |

Dentro do mri_Qadmin (`/adminchar` embutido) as cores e o `/uiconfig` chegam pela bridge
do plugin. Na NUI, as cores passam pelo `suiteColors` do kit (`App.tsx`), o Tailwind usa o
`tailwind-preset` do kit, e janelas e blocos usam `MriCard`/`MriModal` ou as classes
`mri-surface`/`mri-surface-card` para o glass. A moldura cinematográfica sobre a cena 3D
(letterbox, scrims, título e menu da landing) fica em preto e branco de propósito.

## Banco de Dados

O recurso cria automaticamente a tabela `mri_qmultichar_slots` para armazenar os slots personalizados dos jogadores.

## Estrutura

```
mri_Qmultichar/
├── client/
│   └── main.lua          # Lógica principal do cliente
├── server/
│   ├── main.lua          # Callbacks e lógica do servidor
│   └── commands.lua      # Comandos de administração
├── html/
│   ├── src/
│   │   ├── components/   # Componentes React
│   │   ├── lib/          # Utilitários
│   │   └── App.tsx       # Componente principal
│   └── dist/             # Build do frontend (gerado)
├── config.lua            # Configurações
├── fxmanifest.lua        # Manifest do recurso
└── README.md             # Este arquivo
```

## Desenvolvimento

Para desenvolver ou modificar a interface:

1. Entre na pasta `html`:
   ```bash
   cd html
   ```

2. Instale as dependências:
   ```bash
   npm install
   ```

3. Inicie o servidor de desenvolvimento:
   ```bash
   npm run dev
   ```

4. Compile para produção:
   ```bash
   npm run build
   ```

## Funcionalidades

- ✅ Listagem de personagens existentes
- ✅ Criação de novos personagens
- ✅ Deletar personagens
- ✅ Carregar personagem selecionado
- ✅ Preview de personagens
- ✅ Sistema de slots personalizáveis
- ✅ Interface responsiva e moderna

## Dependências

- `qbx_core` - Framework base
- `ox_lib` - Biblioteca de utilitários
- `oxmysql` - MySQL async

## Licença

Este recurso é fornecido como está. Use por sua conta e risco.


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

Edite o arquivo `config.lua` para personalizar:

```lua
Config.CharacterSlots = {
    defaultSlots = 3, -- Número padrão de slots
    maxSlots = 10, -- Número máximo de slots permitidos
}
```

## Banco de Dados

O recurso cria automaticamente a tabela `mri_qmultichar_slots` para armazenar os slots personalizados dos jogadores.

## Estrutura

```
mri_Qmultichar/
├── client/
│   ├── main.lua          # Lógica principal do cliente
│   └── camera.lua        # Sistema de preview com câmera
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


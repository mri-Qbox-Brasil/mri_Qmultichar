# Frontend do mri_Qmultichar

Interface React + Vite + shadcn/ui para o sistema de multichar.

## Instalação

1. Instale as dependências:
```bash
npm install
```

## Desenvolvimento

Para desenvolver a interface:

```bash
npm run dev
```

Isso iniciará um servidor de desenvolvimento Vite na porta 5173.

## Build

Para compilar para produção:

```bash
npm run build
```

Isso gerará os arquivos na pasta `dist/` que serão servidos pelo FiveM.

## Estrutura

- `src/App.tsx` - Componente principal da aplicação
- `src/components/` - Componentes React
  - `CharacterList.tsx` - Lista de personagens
  - `CharacterCard.tsx` - Card de detalhes do personagem
  - `CharacterCreation.tsx` - Formulário de criação
  - `ui/` - Componentes shadcn/ui (Button, Card, Input, Dialog)
- `src/lib/utils.ts` - Funções utilitárias
- `src/index.css` - Estilos globais e tema Tailwind

## Tecnologias

- **React 18** - Biblioteca UI
- **Vite** - Build tool
- **TypeScript** - Tipagem estática
- **Tailwind CSS** - Estilização
- **shadcn/ui** - Componentes UI
- **lucide-react** - Ícones


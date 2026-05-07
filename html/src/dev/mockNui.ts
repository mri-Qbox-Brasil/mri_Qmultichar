
interface MockCharacter {
  citizenid: string
  charinfo: {
    firstname: string
    lastname: string
    gender: number
    birthdate: string
    nationality: string
    account: string
    phone: string
  }
  money: { bank: number; cash: number }
  job: { name: string; label: string; grade: number | { name: string } }
  gang: { label: string; grade: { name: string } }
  cid: number
}

const MOCK_RESOURCE = 'mri_Qmultichar'

const mockAccentColor = '#00E699'

const mockMusic = {
  enabled: true,
  url: '',
  volume: 50,
  loop: true,
  autoplay: false,
}

const mockLocales = {
  characters: {
    title: 'Personagens',
    subtitle: 'Selecione um slot existente ou crie um novo personagem.',
    selection_badge: 'Selecao de personagem',
    select_character: 'Selecione um Personagem',
    select_or_create: 'Escolha um slot na lista ou crie um novo personagem.',
    select_prompt: 'Escolha um slot para visualizar os detalhes.',
    selected_details: 'Detalhes completos do personagem selecionado.',
    confirm_delete_title: 'Confirmar Exclusao',
    confirm_delete: 'Tem certeza que deseja deletar este personagem?',
    delete_warning: 'Esta acao nao pode ser desfeita!',
    no_characters: 'Nenhum personagem criado',
    error_loading_character: 'Erro ao carregar personagem.',
    load_failed: 'Nao foi possivel carregar este personagem.',
    character_info: 'Informacoes do Personagem',
    id_prefix: 'ID',
    slot_label: 'Slot %{slot}',
    job: 'Trabalho',
    grade: 'Grau',
    cash: 'Dinheiro',
    bank: 'Banco',
    gender: 'Genero',
    birthdate: 'Data de Nascimento',
    nationality: 'Nacionalidade',
    gang: 'Gangue',
    unemployed: 'Desempregado',
    male: 'Masculino',
    female: 'Feminino',
    delete_character: 'Deletar Personagem',
  },
  character_creation: {
    title: 'Criacao de Personagem',
    description: 'Preencha os dados iniciais para criar sua identidade.',
    first_name: 'Nome',
    first_name_placeholder: 'Joao',
    last_name: 'Sobrenome',
    last_name_placeholder: 'Silva',
    nationality: 'Nacionalidade',
    nationality_placeholder: 'Nacionalidade',
    nationality_search: 'Buscar nacionalidade',
    nationality_empty: 'Nenhuma nacionalidade encontrada',
    default_nationality: 'Brasileiro',
    gender: 'Genero',
    male: 'Masculino',
    female: 'Feminino',
    birthdate: 'Data de Nascimento',
    birthdate_placeholder: 'DD/MM/AAAA',
    select_birthdate: 'Por favor, selecione uma data de nascimento',
    create: 'Criar',
    creating: 'Criando...',
    create_error: 'Erro ao criar personagem:',
    generic_error: 'Erro ao criar personagem',
    warning_title: 'Aviso',
    months: ['Janeiro', 'Fevereiro', 'Marco', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'],
    week_days: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'],
  },
  settings: {
    title: 'Configuracoes',
    subtitle: 'Ajuste o visual e a experiencia de usuario.',
    theme_section_title: 'Tema da interface',
    theme_select_placeholder: 'Selecione um tema',
    theme_search_placeholder: 'Buscar tema',
    theme_empty: 'Nenhum tema encontrado',
    theme_active_badge: 'Ativo',
    theme_locked_title: 'Mudanca de tema indisponivel',
    theme_locked_description: 'O servidor desativou a troca manual de tema para esta sessao.',
    streamer_mode_title: 'Modo Streamer',
    streamer_active: 'Ativado',
    streamer_inactive: 'Desativado',
    streamer_on_description: 'A musica da tela foi desativada para nao aparecer na transmissao.',
    streamer_off_description: 'Ao ativar o modo streamer a musica do seu menu de selecao de personagem sera desativada',
    streamer_enable: 'Ligar modo streamer',
    streamer_disable: 'Desligar modo streamer',
  },
  buttons: {
    actions: 'Acoes',
    choose_character: 'Selecionar Personagem',
    delete: 'Deletar Personagem',
    cancel: 'Cancelar',
  },
  music_player: {
    youtube_label: 'YouTube',
    audio_label: 'Audio',
    loading_track: 'Carregando faixa...',
    background_music: 'Musica de fundo',
  },
}

const mockCharacters: MockCharacter[] = [
  {
    citizenid: 'ABC12345',
    charinfo: {
      firstname: 'Lucas',
      lastname: 'Silva',
      gender: 0,
      birthdate: '1995-04-12',
      nationality: 'Brazilian',
      account: 'US01XX0000001',
      phone: '5551234',
    },
    money: { bank: 125_000, cash: 4200 },
    job: { name: 'police', label: 'Police Officer', grade: { name: 'Sergeant' } },
    gang: { label: 'None', grade: { name: '0' } },
    cid: 1,
  },
  {
    citizenid: 'DEF67890',
    charinfo: {
      firstname: 'Marina',
      lastname: 'Souza',
      gender: 1,
      birthdate: '1998-09-23',
      nationality: 'Brazilian',
      account: 'US01XX0000002',
      phone: '5559876',
    },
    money: { bank: 38_500, cash: 980 },
    job: { name: 'mechanic', label: 'Mechanic', grade: { name: 'Senior' } },
    gang: { label: 'None', grade: { name: '0' } },
    cid: 2,
  },
  {
    citizenid: 'GHI24680',
    charinfo: {
      firstname: 'Bruno',
      lastname: 'Almeida',
      gender: 0,
      birthdate: '1990-12-01',
      nationality: 'Portuguese',
      account: 'US01XX0000003',
      phone: '5553344',
    },
    money: { bank: 0, cash: 150 },
    job: { name: 'unemployed', label: 'Unemployed', grade: { name: '0' } },
    gang: { label: 'Ballas', grade: { name: 'Member' } },
    cid: 3,
  },
]

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

const mockDefaults = {
  cameraEffects: true,
  cameraEffectType: 'cinema',
  streamerMode: false,
}

function postOpen() {
  window.postMessage(
    {
      action: 'open',
      characters: mockCharacters,
      amount: 4,
      accentColor: mockAccentColor,
      allowAccentOverride: true,
      defaults: mockDefaults,
      music: mockMusic,
      locales: mockLocales,
    },
    '*',
  )
}

function handleMockEndpoint(endpoint: string, payload: unknown): Response | null {
  switch (endpoint) {
    case 'nuiStarted':
      setTimeout(postOpen, 0)
      return jsonResponse({ success: true })
    case 'getCharacters':
      return jsonResponse({
        success: true,
        characters: mockCharacters,
        amount: 4,
        accentColor: mockAccentColor,
        allowAccentOverride: true,
        defaults: mockDefaults,
        music: mockMusic,
        locales: mockLocales,
      })
    case 'getCharacterPhoto':
      return jsonResponse({ success: false })
    case 'getPreviewData':
      return jsonResponse({ success: true })
    case 'setCameraEffects':
      console.info('[dev-mock] setCameraEffects', payload)
      return jsonResponse({ success: true })
    case 'savePhotoBase64':
      return jsonResponse({ success: true })
    case 'loadCharacter':
      console.info('[dev-mock] loadCharacter', payload)
      return jsonResponse({ success: true })
    case 'deleteCharacter':
      console.info('[dev-mock] deleteCharacter', payload)
      return jsonResponse({ success: true })
    case 'createCharacter':
      console.info('[dev-mock] createCharacter', payload)
      return jsonResponse({ success: true })
    default:
      console.warn('[dev-mock] unhandled endpoint:', endpoint)
      return jsonResponse({ success: true })
  }
}

export function installDevMock() {
  ;(window as any).GetParentResourceName = () => MOCK_RESOURCE

  const originalFetch = window.fetch.bind(window)
  window.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url
    const prefix = `https://${MOCK_RESOURCE}/`
    if (url.startsWith(prefix)) {
      const endpoint = url.slice(prefix.length)
      let payload: unknown = undefined
      try {
        payload = init?.body ? JSON.parse(init.body as string) : undefined
      } catch {
      }
      return handleMockEndpoint(endpoint, payload) ?? jsonResponse({ success: true })
    }
    return originalFetch(input as any, init)
  }

  document.documentElement.style.background = '#0b1220'
  document.body.style.background = '#0b1220'

  console.info('[dev-mock] NUI mock installed. Use window.__mriDev to inspect.')
  ;(window as any).__mriDev = {
    characters: mockCharacters,
    accentColor: mockAccentColor,
    locales: mockLocales,
    sendOpen: postOpen,
    sendClose: () => window.postMessage({ action: 'close' }, '*'),
    setAccent: (hex: string) =>
      window.postMessage({ action: 'updateAccentColor', accentColor: hex }, '*'),
  }
}

// Dev-only mock layer. Imported from main.tsx behind `import.meta.env.DEV`,
// so it is fully tree-shaken from production builds.
//
// What it does when running via `npm run dev` in a browser:
//   1. Stubs `GetParentResourceName` so fetch URLs resolve.
//   2. Intercepts `fetch` calls to the NUI handlers (`https://<resource>/...`)
//      and returns plausible mock responses.
//   3. Posts an `open` message to the window so the App reveals itself
//      with fake characters / theme / locales.

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

const mockTheme = {
  name: 'Dark',
  colors: {
    background: 'rgba(2, 6, 23, 0.95)',
    card: 'rgba(15, 23, 42, 0.9)',
    border: 'rgba(51, 65, 85, 0.5)',
    text: { primary: '#F8FAFC', secondary: '#CBD5E1', muted: '#94A3B8' },
    accent: { primary: '#3B82F6', secondary: '#6366F1', success: '#22C55E', danger: '#EF4444' },
    button: { primary: '#3B82F6', primaryHover: '#2563EB', danger: '#EF4444', dangerHover: '#DC2626' },
  },
}

const mockAvailableThemes: Record<string, typeof mockTheme> = {
  dark: mockTheme,
  mri: {
    name: 'MRI',
    colors: {
      background: 'rgba(5, 46, 22, 0.95)',
      card: 'rgba(20, 83, 45, 0.9)',
      border: 'rgba(34, 197, 94, 0.3)',
      text: { primary: '#F0FDF4', secondary: '#DCFCE7', muted: '#BBF7D0' },
      accent: { primary: '#22C55E', secondary: '#4ADE80', success: '#22C55E', danger: '#EF4444' },
      button: { primary: '#22C55E', primaryHover: '#16A34A', danger: '#EF4444', dangerHover: '#DC2626' },
    },
  },
  purple: {
    name: 'Purple',
    colors: {
      background: 'rgba(30, 27, 75, 0.95)',
      card: 'rgba(55, 48, 163, 0.9)',
      border: 'rgba(99, 102, 241, 0.3)',
      text: { primary: '#EEF2FF', secondary: '#E0E7FF', muted: '#C7D2FE' },
      accent: { primary: '#8B5CF6', secondary: '#A78BFA', success: '#22C55E', danger: '#EF4444' },
      button: { primary: '#8B5CF6', primaryHover: '#7C3AED', danger: '#EF4444', dangerHover: '#DC2626' },
    },
  },
}

const mockMusic = {
  enabled: true,
  url: '',
  volume: 50,
  loop: true,
  autoplay: false,
}

const mockLocales = {
  characters: {
    title: 'My Characters',
    subtitle: 'Selecione um slot existente ou crie um novo personagem.',
    select_character: 'Select a Character',
    select_or_create: 'Escolha um slot na lista ou crie um novo personagem.',
    select_prompt: 'Escolha um slot para visualizar os detalhes.',
    selected_details: 'Detalhes completos do personagem selecionado.',
    no_characters: 'Nenhum personagem criado',
    character_info: 'Character Info',
    job: 'Job',
    grade: 'Grade',
    cash: 'Cash',
    bank: 'Bank',
    gender: 'Gender',
    birthdate: 'Birthdate',
    nationality: 'Nationality',
    gang: 'Gang',
    unemployed: 'Unemployed',
    male: 'Male',
    female: 'Female',
  },
  buttons: {
    actions: 'Actions',
    choose_character: 'Choose Character',
    delete: 'Delete Character',
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

function postOpen() {
  window.postMessage(
    {
      action: 'open',
      characters: mockCharacters,
      amount: 4,
      theme: mockTheme,
      music: mockMusic,
      allowThemeChange: true,
      availableThemes: mockAvailableThemes,
      streamerMode: false,
      locales: mockLocales,
    },
    '*',
  )
}

function handleMockEndpoint(endpoint: string, payload: unknown): Response | null {
  switch (endpoint) {
    case 'nuiStarted':
      // Reply to handshake AND trigger the UI to open — by this point the
      // App has registered its `message` listener.
      setTimeout(postOpen, 0)
      return jsonResponse({ success: true })
    case 'getCharacters':
      return jsonResponse({
        success: true,
        characters: mockCharacters,
        amount: 4,
        theme: mockTheme,
        music: mockMusic,
        allowThemeChange: true,
        availableThemes: mockAvailableThemes,
        locales: mockLocales,
      })
    case 'getCharacterPhoto':
      return jsonResponse({ success: false })
    case 'getPreviewData':
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
        // ignore parse errors
      }
      return handleMockEndpoint(endpoint, payload) ?? jsonResponse({ success: true })
    }
    return originalFetch(input as any, init)
  }

  // Make the page visible so the transparent NUI styles don't make it invisible.
  document.documentElement.style.background = '#0b1220'
  document.body.style.background = '#0b1220'

  // The App will send `nuiStarted` via fetch on mount; the mock replies and
  // posts the `open` message back. Exposed helpers for manual testing too.
  console.info('[dev-mock] NUI mock installed. Use window.__mriDev to inspect.')
  ;(window as any).__mriDev = {
    characters: mockCharacters,
    theme: mockTheme,
    availableThemes: mockAvailableThemes,
    locales: mockLocales,
    sendOpen: postOpen,
    sendClose: () => window.postMessage({ action: 'close' }, '*'),
  }
}

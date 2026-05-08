import ptBrLocales from '../../../locales/pt-br.json'

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

const mockLocales = ptBrLocales

const mockMusic = {
  enabled: true,
  url: '',
  volume: 50,
  loop: true,
  autoplay: false,
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

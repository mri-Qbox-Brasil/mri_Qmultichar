import { useState, useEffect, useRef } from 'react'

declare function GetParentResourceName(): string

declare global {
  interface Window {
    YT?: any
    onYouTubeIframeAPIReady?: () => void
  }
}

interface MusicConfig {
  enabled: boolean
  url: string
  volume: number
  loop: boolean
  autoplay?: boolean
}

interface MusicPlayerProps {
  music?: MusicConfig
  theme?: {
    colors: {
      text: {
        primary: string
        muted: string
      }
      accent?: {
        primary?: string
      }
      card?: string
      border?: string
    }
  }
  isStreamerMode?: boolean
}

export function MusicPlayer({ music, theme, isStreamerMode = false }: MusicPlayerProps) {
  const [isPlaying, setIsPlaying] = useState(false)
  const [currentVolume, setCurrentVolume] = useState(music?.volume || 0.3)
  const [isLoading, setIsLoading] = useState(false)
  
  // Escutar mensagens para desativar música (modo streamer)
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.data?.action === 'setStreamerMode') {
        if (event.data.enabled) {
          setIsPlaying(false)
          if (audioRef.current) {
            audioRef.current.pause()
          }
          if (ytPlayerRef.current) {
            ytPlayerRef.current.pauseVideo?.()
          }
        }
      }
    }
    window.addEventListener('message', handleMessage)
    return () => window.removeEventListener('message', handleMessage)
  }, [])
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const ytContainerIdRef = useRef<string>('yt-player-' + Math.random().toString(36).slice(2))
  const ytPlayerRef = useRef<any>(null)
  const isYouTube = !!music?.url && /(youtube\.com\/watch\?v=|youtu\.be\/)/i.test(music.url)
  const [ytTitle, setYtTitle] = useState<string>('')
  const [ytThumb, setYtThumb] = useState<string>('')

  useEffect(() => {
    if (!music) return
    setCurrentVolume(typeof music.volume === 'number' ? music.volume : 0.3)
    setYtTitle('')
    setYtThumb('')
  }, [music?.url, music?.enabled])

  function getYouTubeId(url: string): string | null {
    try {
      const ytWatch = url.match(/[?&]v=([^&#]+)/)
      if (ytWatch && ytWatch[1]) return ytWatch[1]
      const ytShort = url.match(/youtu\.be\/([^?&#/]+)/)
      if (ytShort && ytShort[1]) return ytShort[1]
      return null
    } catch {
      return null
    }
  }

  useEffect(() => {
    if (!music || !music.enabled || !music.url || isStreamerMode) {
      return
    }

    if (isYouTube) {
      const videoId = getYouTubeId(music.url)
      if (!videoId) return

      const ensureApi = () =>
        new Promise<void>((resolve) => {
          if (window.YT && window.YT.Player) {
            resolve()
            return
          }
          const tag = document.createElement('script')
          tag.src = 'https://www.youtube.com/iframe_api'
          const firstScriptTag = document.getElementsByTagName('script')[0]
          firstScriptTag?.parentNode?.insertBefore(tag, firstScriptTag || null)
          window.onYouTubeIframeAPIReady = () => resolve()
        })

      let destroyed = false
      setIsLoading(true)

      ensureApi().then(() => {
        if (destroyed) return
        ytPlayerRef.current = new window.YT.Player(ytContainerIdRef.current, {
          videoId,
          playerVars: {
            autoplay: 0,
            controls: 0,
            rel: 0,
            modestbranding: 1,
            playsinline: 1,
            loop: music.loop ? 1 : 0,
            playlist: music.loop ? videoId : undefined,
          },
          events: {
            onReady: (event: any) => {
              try {
                const iframe: HTMLIFrameElement | null = event?.target?.getIframe?.() || null
                if (iframe) {
                  iframe.setAttribute('allow', 'autoplay; encrypted-media')
                }
                event.target.setVolume(Math.round((music.volume ?? 0.3) * 100))
                // Metadados (título e thumbnail)
                const data = event?.target?.getVideoData?.()
                if (data) {
                  if (data.title) setYtTitle(data.title)
                  const id = data.video_id || videoId
                  if (id) setYtThumb(`https://img.youtube.com/vi/${id}/hqdefault.jpg`)
                } else {
                  setYtTitle('YouTube')
                  setYtThumb(`https://img.youtube.com/vi/${videoId}/hqdefault.jpg`)
                }
              } catch {}

              // Autoplay (melhor esforço). Em CEF geralmente funciona se iniciar mutado.
              if (music.autoplay !== false) {
                try {
                  event.target.mute?.()
                  event.target.playVideo?.()
                  // tentar desmutar depois (pode falhar sem interação do usuário)
                  setTimeout(() => {
                    try {
                      event.target.unMute?.()
                      event.target.setVolume?.(Math.round((music.volume ?? 0.3) * 100))
                    } catch {}
                  }, 700)
                } catch {}
              }
              setIsLoading(false)
            },
            onStateChange: (event: any) => {
              if (event.data === 1) setIsPlaying(true)
              if (event.data === 2) setIsPlaying(false)
              if (event.data === 0) {
                if (music.loop) {
                  event.target.seekTo(0, true)
                  event.target.playVideo()
                } else {
                  setIsPlaying(false)
                }
              }
            },
            onError: () => {
              setIsLoading(false)
              setIsPlaying(false)
            },
          },
        })
      })

      return () => {
        destroyed = true
        try {
          ytPlayerRef.current?.stopVideo?.()
          ytPlayerRef.current?.destroy?.()
        } catch {}
        ytPlayerRef.current = null
      }
    }

    // Criar elemento de áudio para URL direta/arquivo local
    const audio = new Audio()

    let audioUrl = music.url
    if (!music.url.startsWith('http://') && !music.url.startsWith('https://')) {
      try {
        const resourceName = typeof GetParentResourceName !== 'undefined' ? GetParentResourceName() : 'mri_Qmultichar'
        const cleanPath = music.url.replace(/^sounds\//, '')
        audioUrl = `https://${resourceName}/sounds/${cleanPath}`
      } catch {
        const cleanPath = music.url.replace(/^sounds\//, '')
        audioUrl = `./sounds/${cleanPath}`
      }
    }
    
    audio.src = audioUrl
    audio.volume = music.volume ?? 0.3
    audio.loop = music.loop || false
    
    audioRef.current = audio

    // Autoplay para áudio direto (mp3/ogg)
    if (music.autoplay !== false) {
      setIsPlaying(true)
      setIsLoading(true)
    }

    const handleCanPlay = () => {
      setIsLoading(false)
    }

    const handleError = () => {
      console.error('[MusicPlayer] Erro ao carregar música:', audioUrl)
      setIsLoading(false)
      setIsPlaying(false)
    }

    const handleEnded = () => {
      if (!music.loop) {
        setIsPlaying(false)
      }
    }

    audio.addEventListener('canplay', handleCanPlay)
    audio.addEventListener('error', handleError)
    audio.addEventListener('ended', handleEnded)

    return () => {
      audio.removeEventListener('canplay', handleCanPlay)
      audio.removeEventListener('error', handleError)
      audio.removeEventListener('ended', handleEnded)
      audio.pause()
      audio.src = ''
    }
  }, [music, isYouTube])
  
  // Atualizar volume sem recriar o player
  useEffect(() => {
    if (isYouTube) {
      if (ytPlayerRef.current) {
        try {
          ytPlayerRef.current.setVolume?.(Math.round(currentVolume * 100))
        } catch {}
      }
    } else if (audioRef.current) {
      audioRef.current.volume = currentVolume
    }
  }, [currentVolume, isYouTube])

  useEffect(() => {
    if (isYouTube) return
    if (!audioRef.current) return

    if (isPlaying) {
      audioRef.current.play().catch((err) => {
        console.error('[MusicPlayer] Erro ao tocar música:', err)
        setIsPlaying(false)
      })
    } else {
      audioRef.current.pause()
    }
  }, [isPlaying])

  const togglePlay = () => {
    if (!music || !music.enabled || !music.url) return
    
    if (isLoading) return
    
    if (isYouTube) {
      if (!ytPlayerRef.current) return
      const state = ytPlayerRef.current.getPlayerState?.()
      if (state === 1) {
        ytPlayerRef.current.pauseVideo?.()
      } else {
        try {
          ytPlayerRef.current.unMute?.()
          ytPlayerRef.current.setVolume?.(Math.round((currentVolume ?? music.volume ?? 0.3) * 100))
          ytPlayerRef.current.playVideo?.()
        } catch {
          // Fallback: tocar mutado primeiro, depois desmutar
          try {
            ytPlayerRef.current.mute?.()
            ytPlayerRef.current.playVideo?.()
            setTimeout(() => {
              ytPlayerRef.current.unMute?.()
              ytPlayerRef.current.setVolume?.(Math.round((currentVolume ?? music.volume ?? 0.3) * 100))
            }, 150)
          } catch {}
        }
      }
    } else {
      if (!audioRef.current || !audioRef.current.readyState) {
        setIsLoading(true)
        audioRef.current?.load()
        return
      }
      setIsPlaying(!isPlaying)
    }
  }

  const handleVolumeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newVolume = parseFloat(e.target.value)
    setCurrentVolume(newVolume)
    // O useEffect vai atualizar o volume automaticamente
  }

  if (!music || !music.enabled || !music.url) {
    return null
  }

  const accentColor = theme?.colors.accent?.primary || theme?.colors.text.primary || '#3B82F6'
  const textColor = theme?.colors.text.primary || '#FFFFFF'
  const mutedColor = theme?.colors.text.muted || '#94A3B8'
  // Converter cardColor para sólido (remover transparência se houver)
  const cardColorRaw = theme?.colors.card || 'rgba(15, 23, 42, 0.9)'
  let cardColor = cardColorRaw
  if (cardColorRaw.includes('rgba')) {
    // Extrair valores RGB e usar opacidade 1
    const match = cardColorRaw.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/)
    if (match) {
      cardColor = `rgb(${match[1]}, ${match[2]}, ${match[3]})`
    } else {
      cardColor = 'rgb(15, 23, 42)' // Fallback
    }
  }
  const borderColor = theme?.colors.border || 'rgba(51, 65, 85, 0.5)'

  return (
    <div
      style={{
        position: 'relative',
        zIndex: 10000,
        pointerEvents: 'auto',
        backgroundColor: cardColor,
        border: `1px solid ${borderColor}`,
        borderRadius: '12px',
        padding: '12px 16px',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        minWidth: '280px',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.3)',
      }}
      onClick={(e) => e.stopPropagation()}
      onMouseDown={(e) => e.stopPropagation()}
    >
      {/* Botão Play/Pause */}
      <button
        onClick={(e) => {
          e.preventDefault()
          e.stopPropagation()
          togglePlay()
        }}
        onMouseDown={(e) => {
          e.preventDefault()
          e.stopPropagation()
        }}
        disabled={isLoading}
        style={{
          background: 'transparent',
          border: 'none',
          cursor: isLoading ? 'wait' : 'pointer',
          padding: '8px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: textColor,
          transition: 'opacity 0.2s',
          opacity: isLoading ? 0.5 : 1,
          pointerEvents: 'auto',
          zIndex: 10001,
        }}
        onMouseEnter={(e) => {
          if (!isLoading) {
            e.currentTarget.style.opacity = '0.7'
          }
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.opacity = '1'
        }}
      >
        {isLoading ? (
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" strokeDasharray="31.416" strokeDashoffset="15.708">
              <animate attributeName="stroke-dashoffset" values="31.416;0" dur="1s" repeatCount="indefinite" />
            </circle>
          </svg>
        ) : isPlaying ? (
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
          </svg>
        ) : (
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M8 5v14l11-7z" />
          </svg>
        )}
      </button>

      {/* Info do YouTube: thumbnail + título */}
      {isYouTube && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', maxWidth: '220px' }}>
          {ytThumb ? (
            <img
              src={ytThumb}
              alt="thumb"
              style={{ width: '36px', height: '36px', borderRadius: '6px', objectFit: 'cover', border: `1px solid ${borderColor}` }}
            />
          ) : null}
          <span
            style={{
              color: textColor,
              fontSize: '12px',
              maxWidth: '180px',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
            title={ytTitle || music?.url}
          >
            {ytTitle || 'YouTube'}
          </span>
        </div>
      )}

      {/* Container do YouTube (quase invisível, mas dentro da viewport) */}
      {isYouTube && (
        <div
          style={{
            width: 1,
            height: 1,
            position: 'absolute',
            bottom: 0,
            left: 0,
            overflow: 'hidden',
            opacity: 0.01,
            pointerEvents: 'none',
          }}
        >
          <div id={ytContainerIdRef.current} />
        </div>
      )}

      {/* Controle de Volume */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: '8px' }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={mutedColor} strokeWidth="2">
          <path d="M11 5L6 9H2v6h4l5 4V5z" />
          <path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07" />
        </svg>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={currentVolume}
          onChange={handleVolumeChange}
          onClick={(e) => e.stopPropagation()}
          onMouseDown={(e) => e.stopPropagation()}
          style={{
            flex: 1,
            height: '4px',
            background: `linear-gradient(to right, ${accentColor} 0%, ${accentColor} ${currentVolume * 100}%, ${borderColor} ${currentVolume * 100}%, ${borderColor} 100%)`,
            borderRadius: '2px',
            outline: 'none',
            cursor: 'pointer',
            pointerEvents: 'auto',
            zIndex: 10001,
          }}
        />
        <span style={{ color: mutedColor, fontSize: '12px', minWidth: '30px', textAlign: 'right' }}>
          {Math.round(currentVolume * 100)}%
        </span>
      </div>
    </div>
  )
}


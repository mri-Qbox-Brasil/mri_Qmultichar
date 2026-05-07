import { useEffect, useRef, useState } from 'react'
import { MriBadge, MriButton, MriCard, MriSpinner } from '@mriqbox/ui-kit'
import { Pause, Play, Volume2 } from 'lucide-react'
import type { UiTheme } from '../lib/mriTheme'

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
  theme?: UiTheme
  isStreamerMode?: boolean
  locales?: any
}

export function MusicPlayer({ music, theme, isStreamerMode = false, locales = {} }: MusicPlayerProps) {
  const [isPlaying, setIsPlaying] = useState(false)
  const [currentVolume, setCurrentVolume] = useState(music?.volume || 0.3)
  const [isLoading, setIsLoading] = useState(false)
  const [prevStreamerMode, setPrevStreamerMode] = useState(isStreamerMode)
  const [ytTitle, setYtTitle] = useState('')
  const [ytThumb, setYtThumb] = useState('')
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const ytContainerIdRef = useRef(`yt-player-${Math.random().toString(36).slice(2)}`)
  const ytPlayerRef = useRef<any>(null)
  const isYouTube = !!music?.url && /(youtube\.com\/watch\?v=|youtu\.be\/)/i.test(music.url)

  useEffect(() => {
    if (prevStreamerMode && !isStreamerMode) {
      if (audioRef.current) {
        audioRef.current.src = ''
        audioRef.current = null
      }

      if (ytPlayerRef.current) {
        try {
          ytPlayerRef.current.destroy?.()
        } catch {}

        ytPlayerRef.current = null
      }
    }

    setPrevStreamerMode(isStreamerMode)
  }, [isStreamerMode, prevStreamerMode])

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.data?.action === 'setStreamerMode') {
        if (event.data.enabled) {
          setIsPlaying(false)

          if (audioRef.current) {
            audioRef.current.pause()
            audioRef.current.src = ''
          }

          if (ytPlayerRef.current) {
            try {
              ytPlayerRef.current.pauseVideo?.()
              ytPlayerRef.current.stopVideo?.()
            } catch {}
          }
        } else if (music && music.enabled && music.url) {
          setIsPlaying(true)

          if (isYouTube && ytPlayerRef.current) {
            try {
              ytPlayerRef.current.playVideo?.()
            } catch {}
          } else if (audioRef.current) {
            audioRef.current.play().catch(console.error)
          }
        }
      }
    }

    window.addEventListener('message', handleMessage)
    return () => window.removeEventListener('message', handleMessage)
  }, [isYouTube, music])

  useEffect(() => {
    if (!music) return
    setCurrentVolume(typeof music.volume === 'number' ? music.volume : 0.3)
    setYtTitle('')
    setYtThumb('')
  }, [music?.enabled, music?.url])

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
    if (isStreamerMode) {
      if (audioRef.current) {
        audioRef.current.pause()
        audioRef.current.src = ''
      }

      if (ytPlayerRef.current) {
        try {
          ytPlayerRef.current.pauseVideo?.()
          ytPlayerRef.current.stopVideo?.()
        } catch {}
      }

      setIsPlaying(false)
      return
    }

    if (!music || !music.enabled || !music.url) {
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

              if (music.autoplay !== false) {
                try {
                  event.target.mute?.()
                  event.target.playVideo?.()

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

    if (music.autoplay !== false) {
      setIsPlaying(true)
      setIsLoading(true)
    }

    const handleCanPlay = () => setIsLoading(false)
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
  }, [isStreamerMode, isYouTube, music])

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
    if (isYouTube || !audioRef.current) return

    if (isPlaying) {
      audioRef.current.play().catch((err) => {
        console.error('[MusicPlayer] Erro ao tocar música:', err)
        setIsPlaying(false)
      })
    } else {
      audioRef.current.pause()
    }
  }, [isPlaying, isYouTube])

  const togglePlay = () => {
    if (!music || !music.enabled || !music.url || isLoading) return

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

      setIsPlaying((prev) => !prev)
    }
  }

  const handleVolumeChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setCurrentVolume(Number.parseFloat(event.target.value))
  }

  if (isStreamerMode || !music || !music.enabled || !music.url) {
    return null
  }

  const accentColor = theme?.colors.accent?.primary || theme?.colors.text.primary || '#00FFA3'
  const mutedColor = theme?.colors.text.muted || '#A1A1AA'
  const borderColor = theme?.colors.border || 'rgba(39, 39, 42, 0.6)'

  return (
    <MriCard
      className="flex min-w-[320px] max-w-[420px] items-center gap-4 rounded-[1.5rem] border border-border/80 px-4 py-3 shadow-2xl shadow-black/25"
      style={{ pointerEvents: 'auto' }}
      onClick={(event) => event.stopPropagation()}
      onMouseDown={(event) => event.stopPropagation()}
    >
      <MriButton
        variant="ghost"
        size="icon"
        className="h-12 w-12 shrink-0 rounded-2xl border border-border/80 bg-background"
        disabled={isLoading}
        onClick={(event) => {
          event.preventDefault()
          event.stopPropagation()
          togglePlay()
        }}
      >
        {isLoading ? (
          <MriSpinner size="sm" />
        ) : isPlaying ? (
          <Pause className="h-4 w-4" />
        ) : (
          <Play className="h-4 w-4" />
        )}
      </MriButton>

      <div className="min-w-0 flex-1 space-y-2">
        <div className="flex items-center gap-2">
          <MriBadge variant={isYouTube ? 'default' : 'secondary'} className="rounded-full px-2.5 py-0.5 text-[10px] uppercase tracking-[0.18em]">
            {isYouTube
              ? (locales.music_player?.youtube_label || 'YouTube')
              : (locales.music_player?.audio_label || 'Audio')}
          </MriBadge>
          <span className="truncate text-sm font-medium text-foreground" title={ytTitle || music.url}>
            {isYouTube
              ? (ytTitle || locales.music_player?.loading_track || 'Carregando faixa...')
              : (locales.music_player?.background_music || 'Música de fundo')}
          </span>
        </div>

        <div className="flex items-center gap-3">
          {isYouTube && ytThumb ? (
            <img
              src={ytThumb}
              alt="thumb"
              className="h-10 w-10 rounded-xl object-cover"
              style={{ border: `1px solid ${borderColor}` }}
            />
          ) : (
            <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-border/80 bg-background text-primary">
              <Volume2 className="h-4 w-4" />
            </div>
          )}

          <div className="flex min-w-0 flex-1 items-center gap-2">
            <Volume2 className="h-4 w-4 shrink-0" style={{ color: mutedColor }} />
            <input
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={currentVolume}
              onChange={handleVolumeChange}
              onClick={(event) => event.stopPropagation()}
              onMouseDown={(event) => event.stopPropagation()}
              className="h-1.5 w-full cursor-pointer appearance-none rounded-full bg-transparent"
              style={{
                background: `linear-gradient(to right, ${accentColor} 0%, ${accentColor} ${currentVolume * 100}%, ${borderColor} ${currentVolume * 100}%, ${borderColor} 100%)`,
              }}
            />
            <span className="w-10 text-right text-xs text-muted-foreground">
              {Math.round(currentVolume * 100)}%
            </span>
          </div>
        </div>
      </div>

      {isYouTube && (
        <div
          className="pointer-events-none absolute bottom-0 left-0 h-px w-px overflow-hidden opacity-[0.01]"
          aria-hidden="true"
        >
          <div id={ytContainerIdRef.current} />
        </div>
      )}
    </MriCard>
  )
}

import { useState, useEffect, useRef } from 'react'

interface GlitchNameProps {
  name: string
  theme?: {
    colors: {
      text: {
        primary: string
      }
      accent?: {
        primary?: string
      }
    }
  }
}

const SYMBOLS = '!@#$%^&*()_+-=[]{}|;:,.<>?~`0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

export function GlitchName({ name, theme }: GlitchNameProps) {
  const [displayText, setDisplayText] = useState<string>('')
  const [isAnimating, setIsAnimating] = useState(false)
  const animationRef = useRef<number>()

  useEffect(() => {
    if (!name) {
      setDisplayText('')
      setIsAnimating(false)
      return
    }

    setIsAnimating(true)
    setDisplayText('')

    const targetLength = name.length
    let currentIndex = 0
    const revealSpeed = 3 // Revelar um caractere a cada X frames
    let frame = 0
    const maxFrames = targetLength * revealSpeed + 30 // Frames extras para animação final

    const animate = () => {
      if (frame < maxFrames) {
        // Gerar texto com símbolos se misturando
        let randomText = ''
        for (let i = 0; i < targetLength; i++) {
          if (i < currentIndex) {
            // Caracteres já revelados mostram o nome correto
            randomText += name[i]
          } else if (i === currentIndex && frame % revealSpeed === 0) {
            // No momento de revelar, mostrar o caractere correto
            randomText += name[i]
          } else {
            // Caracteres não revelados mostram símbolos/letras aleatórias
            // Misturar símbolos e letras para efeito mais interessante
            if (Math.random() > 0.5) {
              randomText += SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)]
            } else {
              randomText += CHARS[Math.floor(Math.random() * CHARS.length)]
            }
          }
        }
        setDisplayText(randomText)

        frame++

        // Revelar próximo caractere
        if (frame % revealSpeed === 0 && currentIndex < targetLength) {
          currentIndex++
        }

        animationRef.current = requestAnimationFrame(animate)
      } else {
        // Mostrar o nome final
        setDisplayText(name)
        setIsAnimating(false)
      }
    }

    animationRef.current = requestAnimationFrame(animate)

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
    }
  }, [name])

  if (!name) return null

  const accentColor = theme?.colors.accent?.primary || theme?.colors.text.primary || '#3B82F6'
  const textColor = theme?.colors.text.primary || '#FFFFFF'

  return (
    <div
      className="glitch-name-container"
      style={{
        position: 'absolute',
        top: '40px',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 1000,
        textAlign: 'center',
        pointerEvents: 'none',
        width: '100%',
      }}
    >
      <h1
        className="glitch-name-text"
        style={{
          fontSize: '4rem',
          fontWeight: '900',
          color: textColor,
          textShadow: `
            0 0 10px ${accentColor}40,
            0 0 20px ${accentColor}60,
            0 0 30px ${accentColor}80,
            0 0 40px ${accentColor},
            0 0 70px ${accentColor},
            0 0 100px ${accentColor}80
          `,
          letterSpacing: '0.1em',
          fontFamily: 'Inter, "Outfit", system-ui, -apple-system, sans-serif',
          textTransform: 'none',
          animation: isAnimating ? 'glitch 0.15s infinite, pulse 2s ease-in-out infinite' : 'pulse 2s ease-in-out infinite',
          userSelect: 'none',
          whiteSpace: 'nowrap',
          filter: isAnimating ? 'blur(0.5px)' : 'blur(0px)',
          transition: 'filter 0.3s ease-out',
        }}
      >
        {displayText || name}
      </h1>
      <style>{`
        @keyframes glitch {
          0%, 100% {
            transform: translate(0);
            text-shadow: 
              0 0 10px ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor},
              0 0 100px ${accentColor}80;
          }
          10% {
            transform: translate(-1px, 1px);
            text-shadow: 
              -2px 0 ${accentColor}80,
              2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
          20% {
            transform: translate(1px, -1px);
            text-shadow: 
              2px 0 ${accentColor}80,
              -2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
          30% {
            transform: translate(-1px, -1px);
            text-shadow: 
              -2px 0 ${accentColor}80,
              2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
          40% {
            transform: translate(1px, 1px);
            text-shadow: 
              2px 0 ${accentColor}80,
              -2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
          50% {
            transform: translate(0);
            text-shadow: 
              0 0 10px ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor},
              0 0 100px ${accentColor}80;
          }
          60% {
            transform: translate(-1px, 1px);
            text-shadow: 
              -2px 0 ${accentColor}80,
              2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
          70% {
            transform: translate(1px, -1px);
            text-shadow: 
              2px 0 ${accentColor}80,
              -2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
          80% {
            transform: translate(-1px, -1px);
            text-shadow: 
              -2px 0 ${accentColor}80,
              2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
          90% {
            transform: translate(1px, 1px);
            text-shadow: 
              2px 0 ${accentColor}80,
              -2px 0 ${accentColor}40,
              0 0 20px ${accentColor}60,
              0 0 30px ${accentColor}80,
              0 0 40px ${accentColor},
              0 0 70px ${accentColor};
          }
        }
        
        @keyframes pulse {
          0%, 100% {
            opacity: 1;
            filter: brightness(1);
          }
          50% {
            opacity: 0.9;
            filter: brightness(1.1);
          }
        }
      `}</style>
    </div>
  )
}


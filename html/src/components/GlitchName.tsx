import { useState, useEffect, useRef } from 'react'

interface GlitchNameProps {
  name: string
  accentColor?: string
}


const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

export function GlitchName({ name, accentColor: accentProp }: GlitchNameProps) {
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
    const revealSpeed = 2 
    let frame = 0
    const maxFrames = targetLength * revealSpeed + 10

    const animate = () => {
      if (frame < maxFrames) {
        let randomText = ''
        for (let i = 0; i < targetLength; i++) {
          if (i < currentIndex) {
            randomText += name[i]
          } else {
            randomText += CHARS[Math.floor(Math.random() * CHARS.length)]
          }
        }
        setDisplayText(randomText)
        frame++

        if (frame % revealSpeed === 0 && currentIndex < targetLength) {
          currentIndex++
        }

        animationRef.current = requestAnimationFrame(animate)
      } else {
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

  const accentColor = accentProp || '#00E699'
  const textColor = '#FFFFFF'

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
          textTransform: 'uppercase',
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


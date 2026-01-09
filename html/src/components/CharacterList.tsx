import { useState, useEffect } from 'react'
import { Plus, Briefcase, Wallet, Sparkles } from 'lucide-react'
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar'
import { Badge } from './ui/badge'
import { Skeleton } from './ui/skeleton'
import { cn } from '@/lib/utils'
import type { Character } from '../App'

declare function GetParentResourceName(): string

interface Theme {
  colors: {
    background: string
    card: string
    border: string
    text: {
      primary: string
      secondary: string
      muted: string
    }
    accent: {
      primary: string
      secondary: string
      success: string
      danger: string
    }
    button: {
      primary: string
      primaryHover: string
      danger: string
      dangerHover: string
    }
  }
}

interface CharacterListProps {
  characters: Character[]
  maxSlots: number
  selectedCharacter: Character | null
  onSelect: (character: Character) => void
  onCreate: (slot: number) => void
  theme: Theme | null
  characterPhotos?: Record<string, string>
}

export function CharacterList({ 
  characters, 
  maxSlots, 
  selectedCharacter,
  onSelect, 
  onCreate,
  theme,
  characterPhotos: externalPhotos = {}
}: CharacterListProps) {
  const slots = Array.from({ length: maxSlots }, (_, i) => i + 1)
  const [characterPhotos, setCharacterPhotos] = useState<Record<string, string>>(externalPhotos)
  const [loadingPhotos, setLoadingPhotos] = useState(true)

  // Carregar fotos dos personagens
  useEffect(() => {
    // Usar fotos externas se disponíveis
    if (Object.keys(externalPhotos).length > 0) {
      setCharacterPhotos(externalPhotos)
      setLoadingPhotos(false)
      return
    }
    
    const loadPhotos = async () => {
      setLoadingPhotos(true)
      const photos: Record<string, string> = {}
      for (const character of characters) {
        try {
          const response = await fetch(`https://${GetParentResourceName()}/getCharacterPhoto`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ citizenid: character.citizenid }),
          })
          const data = await response.json()
          if (data.success && data.photo) {
            photos[character.citizenid] = data.photo
          }
        } catch (error) {
          console.error('Erro ao carregar foto:', error)
        }
      }
      setCharacterPhotos(photos)
      setLoadingPhotos(false)
    }
    
    if (characters.length > 0) {
      loadPhotos()
    } else {
      setLoadingPhotos(false)
    }
  }, [characters, externalPhotos])

  const getCharacterForSlot = (slot: number): Character | undefined => {
    // Buscar personagem pelo cid que corresponde exatamente ao slot
    const byCid = characters.find(char => char.cid === slot)
    if (byCid) return byCid
    
    // Se não encontrou por cid, verificar se há personagem disponível
    // que não está sendo usado em outro slot
    const usedCitizenIds = new Set<string>()
    slots.forEach(s => {
      if (s !== slot) {
        const char = characters.find(c => c.cid === s)
        if (char) usedCitizenIds.add(char.citizenid)
      }
    })
    
    // Encontrar primeiro personagem não usado
    for (const char of characters) {
      if (!usedCitizenIds.has(char.citizenid)) {
        // Se o personagem não tem cid ou tem cid null, pode ser usado
        if (!char.cid || char.cid === slot) {
          return char
        }
      }
    }
    
    return undefined
  }

  const getInitials = (firstname: string, lastname: string) => {
    return `${firstname[0]}${lastname[0]}`.toUpperCase()
  }

  const getAvatarGradient = (index: number) => {
    const gradients = [
      'from-blue-500 via-purple-500 to-pink-500',
      'from-emerald-500 via-teal-500 to-cyan-500',
      'from-orange-500 via-red-500 to-pink-500',
      'from-indigo-500 via-blue-500 to-cyan-500',
      'from-violet-500 via-purple-500 to-fuchsia-500',
      'from-amber-500 via-orange-500 to-red-500',
      'from-green-500 via-emerald-500 to-teal-500',
      'from-rose-500 via-pink-500 to-fuchsia-500',
      'from-sky-500 via-blue-500 to-indigo-500',
      'from-lime-500 via-green-500 to-emerald-500',
    ]
    return gradients[index % gradients.length]
  }

  return (
    <div className="p-6 space-y-4">
      {slots.map((slot) => {
        const character = getCharacterForSlot(slot)
        const isSelected = selectedCharacter?.citizenid === character?.citizenid
        const isEmpty = !character

        return (
          <div
            key={`slot-${slot}-${character?.citizenid || 'empty'}`}
            onClick={() => {
              if (character) {
                onSelect(character)
              } else {
                onCreate(slot)
              }
            }}
            className={cn(
              "group relative flex items-center gap-4 p-4 rounded-2xl cursor-pointer",
              "transition-all duration-300 ease-out",
              "hover:scale-[1.02] hover:shadow-xl",
              "border",
              isEmpty && "hover:border-opacity-60",
              isSelected && "ring-2 ring-offset-2 ring-offset-transparent",
              "animate-in fade-in slide-in-from-left-4"
            )}
            style={{
              backgroundColor: isSelected 
                ? `${theme?.colors.accent.primary || '#3B82F6'}15` 
                : isEmpty
                ? 'rgba(255, 255, 255, 0.02)'
                : 'rgba(255, 255, 255, 0.04)',
              borderColor: isSelected 
                ? `${theme?.colors.accent.primary || '#3B82F6'}60` 
                : theme?.colors.border || 'rgba(51, 65, 85, 0.3)',
              animationDelay: `${(slot - 1) * 0.08}s`,
              boxShadow: isSelected 
                ? `0 8px 32px ${theme?.colors.accent.primary || '#3B82F6'}20` 
                : '0 4px 16px rgba(0, 0, 0, 0.1)',
            }}
          >
            {/* Glow effect on hover */}
            {isSelected && (
              <div 
                className="absolute inset-0 rounded-2xl opacity-20 blur-xl -z-10"
                style={{
                  background: `radial-gradient(circle, ${theme?.colors.accent.primary || '#3B82F6'} 0%, transparent 70%)`,
                }}
              />
            )}

            {/* Avatar with gradient */}
            <div className="relative">
              {loadingPhotos && character ? (
                <Skeleton className="w-16 h-16 rounded-full" />
              ) : (
                <Avatar 
                  className={cn(
                    "w-16 h-16 border-2 transition-all duration-300",
                    "group-hover:scale-110 group-hover:rotate-3",
                    isEmpty 
                      ? "bg-gradient-to-br from-slate-700/50 to-slate-800/50 border-slate-600/30"
                      : `bg-gradient-to-br ${getAvatarGradient(slot - 1)} border-white/20 shadow-lg`
                  )}
                >
                  {character && characterPhotos[character.citizenid] ? (
                    <AvatarImage 
                      src={characterPhotos[character.citizenid]} 
                      alt={`${character.charinfo.firstname} ${character.charinfo.lastname}`}
                      className="object-cover w-full h-full"
                    />
                  ) : null}
                  <AvatarFallback 
                    className={cn(
                      "text-lg font-bold",
                      isEmpty ? "text-slate-400" : "text-white"
                    )}
                  >
                    {character ? (
                      getInitials(character.charinfo.firstname, character.charinfo.lastname)
                    ) : (
                      <Plus className="w-6 h-6" />
                    )}
                  </AvatarFallback>
                </Avatar>
              )}
              
              {/* Status indicator */}
              {character && !loadingPhotos && (
                <div 
                  className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full border-2 flex items-center justify-center shadow-lg animate-pulse"
                  style={{
                    backgroundColor: theme?.colors.accent.primary || '#3B82F6',
                    borderColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                  }}
                >
                  <Sparkles className="w-3 h-3 text-white" />
                </div>
              )}
            </div>

            {/* Info */}
            <div className="flex-1 min-w-0 space-y-1">
              <div className="flex items-center gap-2">
                <h3 
                  className={cn(
                    "font-bold text-base truncate transition-colors",
                    isSelected && "bg-gradient-to-r bg-clip-text text-transparent"
                  )}
                  style={isSelected ? {
                    backgroundImage: `linear-gradient(to right, ${theme?.colors.accent.primary || '#3B82F6'}, ${theme?.colors.accent.secondary || '#8B5CF6'})`,
                  } : {
                    color: theme?.colors.text.primary || '#FFFFFF'
                  }}
                >
                  {character 
                    ? `${character.charinfo.firstname} ${character.charinfo.lastname}`
                    : `Slot ${slot}`
                  }
                </h3>
              </div>
              
              {character ? (
                <div className="flex items-center gap-3 flex-wrap">
                  <Badge 
                    variant="outline"
                    className="text-xs px-2 py-0.5 border-opacity-30 bg-opacity-10"
                    style={{
                      borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                      color: theme?.colors.text.secondary || '#CBD5E1',
                      backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    }}
                  >
                    <Briefcase className="w-3 h-3 mr-1" />
                    {character.job?.label || 'Unemployed'}
                  </Badge>
                  
                  <div className="flex items-center gap-1 text-xs opacity-70" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                    <Wallet className="w-3 h-3" />
                    <span>${(character.money?.cash || 0).toLocaleString()}</span>
                  </div>
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <div 
                    className="w-1.5 h-1.5 rounded-full animate-pulse"
                    style={{ backgroundColor: theme?.colors.accent?.primary || '#3B82F6' }}
                  />
                  <p 
                    className="text-sm"
                    style={{ color: theme?.colors.text.muted || '#94A3B8' }}
                  >
                    Clique para criar personagem
                  </p>
                </div>
              )}
            </div>

            {/* Arrow indicator */}
            <div 
              className={cn(
                "w-8 h-8 rounded-full flex items-center justify-center transition-all duration-300",
                "opacity-0 group-hover:opacity-100 group-hover:translate-x-1",
                isSelected && "opacity-100"
              )}
              style={{
                backgroundColor: isSelected 
                  ? `${theme?.colors.accent.primary || '#3B82F6'}20` 
                  : 'rgba(255, 255, 255, 0.05)',
              }}
            >
              <svg 
                className="w-5 h-5" 
                fill="none" 
                stroke="currentColor" 
                viewBox="0 0 24 24"
                style={{ color: theme?.colors.accent.primary || '#3B82F6' }}
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </div>
          </div>
        )
      })}
    </div>
  )
}

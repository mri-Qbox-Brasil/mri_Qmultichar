import { User, Plus, Crown } from 'lucide-react'
import type { Character } from '../App'

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
}

export function CharacterList({ 
  characters, 
  maxSlots, 
  selectedCharacter,
  onSelect, 
  onCreate,
  theme
}: CharacterListProps) {
  const slots = Array.from({ length: maxSlots }, (_, i) => i + 1)

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

  return (
    <div className="p-4 space-y-2">
      {slots.map((slot) => {
        const character = getCharacterForSlot(slot)
        const isSelected = selectedCharacter?.citizenid === character?.citizenid

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
            className="flex items-center gap-3 p-3 rounded-xl cursor-pointer transition-all hover:scale-[1.02] animate-fade-in"
            style={{
              backgroundColor: isSelected 
                ? 'rgba(255, 255, 255, 0.08)' 
                : 'rgba(255, 255, 255, 0.03)',
              border: `1px solid ${isSelected 
                ? theme?.colors.accent.primary || 'rgba(59, 130, 246, 0.5)' 
                : theme?.colors.border || 'rgba(51, 65, 85, 0.5)'}`,
              animationDelay: `${(slot - 1) * 0.05}s`
            }}
          >
            {/* Avatar */}
            <div className={`
              w-12 h-12 rounded-full flex items-center justify-center
              ${character 
                ? 'bg-blue-500/20 border border-blue-400/30' 
                : 'bg-gray-700/30 border border-gray-600/30'
              }
            `}>
              {character ? (
                <User className="w-6 h-6 text-blue-300" />
              ) : (
                <Plus className="w-6 h-6 text-gray-400" />
              )}
            </div>

            {/* Info */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <p 
                  className="font-semibold text-sm truncate"
                  style={{ color: isSelected ? theme?.colors.text.primary || '#FFFFFF' : theme?.colors.text.secondary || '#E5E7EB' }}
                >
                  {character 
                    ? `${character.charinfo.firstname} ${character.charinfo.lastname}`
                    : `Slot ${slot}`
                  }
                </p>
                {character && (
                  <Crown className="w-3.5 h-3.5 text-yellow-400 flex-shrink-0" />
                )}
              </div>
              <p 
                className="text-xs truncate mt-0.5"
                style={{ color: isSelected ? theme?.colors.text.secondary || '#D1D5DB' : theme?.colors.text.muted || '#9CA3AF' }}
              >
                {character?.job?.label || 'Empty Slot'}
              </p>
            </div>
          </div>
        )
      })}
    </div>
  )
}

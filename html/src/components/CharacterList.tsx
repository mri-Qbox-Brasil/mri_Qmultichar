import { useEffect, useState } from 'react'
import { MriBadge, MriCard } from '@mriqbox/ui-kit'
import { Briefcase, ChevronRight, Plus, Sparkles, Wallet } from 'lucide-react'
import { Avatar, AvatarFallback, AvatarImage } from './ui/avatar'
import { Skeleton } from './ui/skeleton'
import { cn } from '@/lib/utils'
import type { UiTheme } from '@/lib/mriTheme'
import type { Character } from '../App'

declare function GetParentResourceName(): string

interface CharacterListProps {
  characters: Character[]
  maxSlots: number
  selectedCharacter: Character | null
  onSelect: (character: Character) => void
  onCreate: (slot: number) => void
  theme: UiTheme | null
  characterPhotos?: Record<string, string>
  locales?: any
}

export function CharacterList({
  characters,
  maxSlots,
  selectedCharacter,
  onSelect,
  onCreate,
  theme: _theme,
  characterPhotos: externalPhotos = {},
  locales = {},
}: CharacterListProps) {
  const slots = Array.from({ length: maxSlots }, (_, index) => index + 1)
  const [characterPhotos, setCharacterPhotos] = useState<Record<string, string>>(externalPhotos)
  const [loadingPhotos, setLoadingPhotos] = useState(true)

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const data = event.data

      if (data && data.action === 'characterPhotoReady' && data.photo) {
        setCharacterPhotos((prev) => ({
          ...prev,
          [data.citizenid]: data.photo,
        }))
      }
    }

    window.addEventListener('message', handleMessage)
    return () => window.removeEventListener('message', handleMessage)
  }, [])

  useEffect(() => {
    if (Object.keys(externalPhotos).length > 0) {
      setCharacterPhotos(externalPhotos)
    }
  }, [externalPhotos])

  useEffect(() => {
    const loadPhotos = async () => {
      setLoadingPhotos(true)
      const photos: Record<string, string> = {}

      for (const character of characters) {
        if (characterPhotos[character.citizenid]) continue

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

      setCharacterPhotos((prev) => ({ ...prev, ...photos }))
      setLoadingPhotos(false)
    }

    if (characters.length > 0) {
      loadPhotos()
    } else {
      setLoadingPhotos(false)
    }
  }, [characters])

  const getCharacterForSlot = (slot: number): Character | undefined => {
    const byCid = characters.find((character) => character.cid === slot)
    if (byCid) return byCid

    const usedCitizenIds = new Set<string>()
    slots.forEach((currentSlot) => {
      if (currentSlot !== slot) {
        const character = characters.find((candidate) => candidate.cid === currentSlot)
        if (character) {
          usedCitizenIds.add(character.citizenid)
        }
      }
    })

    for (const character of characters) {
      if (!usedCitizenIds.has(character.citizenid) && (!character.cid || character.cid === slot)) {
        return character
      }
    }

    return undefined
  }

  const getInitials = (firstname: string, lastname: string) => `${firstname[0]}${lastname[0]}`.toUpperCase()



  return (
    <div className="space-y-4 p-6">
      {slots.map((slot) => {
        const character = getCharacterForSlot(slot)
        const isSelected = selectedCharacter?.citizenid === character?.citizenid
        const isEmpty = !character

        return (
          <MriCard
            key={`slot-${slot}-${character?.citizenid || 'empty'}`}
            className={cn(
              'group relative cursor-pointer overflow-hidden rounded-[1.75rem] border p-4',
              isSelected
                ? 'border-primary/45'
                : 'border-border/80 hover:border-primary/30',
              isEmpty && 'border-dashed',
            )}
            style={{ opacity: 1 }}
            onClick={() => {
              if (character) {
                onSelect(character)
              } else {
                onCreate(slot)
              }
            }}
          >
            {isSelected && (
              <div className="absolute inset-y-4 left-0 w-1 rounded-r-full bg-primary" />
            )}

            <div className="flex items-center gap-4">
              <div className="relative">
                {loadingPhotos && character ? (
                  <Skeleton className="h-16 w-16 rounded-[1.35rem]" />
                ) : (
                  <Avatar
                    className={cn(
                      'h-16 w-16 rounded-[1.35rem] border border-white/10 group-hover:scale-105',
                      isEmpty ? 'bg-[#0f1115]/95' : 'bg-black',
                    )}
                  >
                    {character && characterPhotos[character.citizenid] ? (
                      <AvatarImage
                        src={characterPhotos[character.citizenid]}
                        alt={`${character.charinfo.firstname} ${character.charinfo.lastname}`}
                        className="object-cover"
                      />
                    ) : null}
                    <AvatarFallback className="rounded-[1.15rem] bg-[#0f1115]/95 text-base font-semibold text-foreground">
                      {character ? getInitials(character.charinfo.firstname, character.charinfo.lastname) : <Plus className="h-5 w-5" />}
                    </AvatarFallback>
                  </Avatar>
                )}

                {character && !loadingPhotos && (
                  <span className="absolute -bottom-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full border border-card bg-primary text-primary-foreground">
                    <Sparkles className="h-3 w-3" />
                  </span>
                )}
              </div>

              <div className="min-w-0 flex-1 space-y-2">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <h3 className="truncate text-base font-semibold text-foreground">
                      {character
                        ? `${character.charinfo.firstname} ${character.charinfo.lastname}`
                        : (locales.characters?.slot_label?.replace('%{slot}', String(slot)) || `Slot ${slot}`)}
                    </h3>
                    {character && (
                      <p className="mt-1 truncate text-xs uppercase tracking-[0.18em] text-muted-foreground">
                        {locales.characters?.id_prefix || 'ID'} {character.citizenid}
                      </p>
                    )}
                  </div>

                  <ChevronRight className={cn(
                    'mt-1 h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-300 group-hover:translate-x-1 group-hover:text-primary',
                    isSelected && 'text-primary',
                  )} />
                </div>

                {character && (
                  <div className="flex flex-wrap items-center gap-2">
                    <MriBadge variant="secondary" className="rounded-full px-2.5 py-1 text-[11px] font-medium">
                      <Briefcase className="mr-1 h-3 w-3" />
                      {character.job?.label || locales.characters?.unemployed || 'Unemployed'}
                    </MriBadge>
                    <MriBadge variant="outline" className="rounded-full px-2.5 py-1 text-[11px] font-medium text-muted-foreground">
                      <Wallet className="mr-1 h-3 w-3" />
                      ${(character.money?.cash || 0).toLocaleString()}
                    </MriBadge>
                  </div>
                )}
              </div>
            </div>
          </MriCard>
        )
      })}
    </div>
  )
}

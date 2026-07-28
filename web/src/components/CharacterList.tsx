import { useEffect, useState } from 'react'
import { Briefcase, ChevronRight, Plus, Sparkles, Wallet, Users } from 'lucide-react'
import { Avatar, AvatarFallback, AvatarImage } from './ui/avatar'
import { Skeleton } from './ui/skeleton'
import { cn } from '@/lib/utils'
import type { Character } from '../App'

declare function GetParentResourceName(): string

interface CharacterListProps {
  characters: Character[]
  maxSlots: number
  selectedCharacter: Character | null
  onSelect: (character: Character) => void
  onCreate: (slot: number) => void
  characterPhotos?: Record<string, string>
  locales?: any
}

export function CharacterList({
  characters,
  maxSlots,
  selectedCharacter,
  onSelect,
  onCreate,
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
    // 1. Tenta encontrar um personagem mapeado exatamente para este slot (por cid)
    const byCid = characters.find((character) => character.cid === slot)
    if (byCid) return byCid

    // 2. Identifica todos os personagens que já estão mapeados para algum dos slots visíveis
    const mappedCitizenIds = new Set<string>()
    slots.forEach((currentSlot) => {
      const char = characters.find((candidate) => candidate.cid === currentSlot)
      if (char) {
        mappedCitizenIds.add(char.citizenid)
      }
    })

    // 3. Encontra personagens que não estão mapeados em nenhum dos slots visíveis (ex: cid maior que maxSlots, ou nulo)
    const unmappedCharacters = characters.filter((char) => !mappedCitizenIds.has(char.citizenid))

    // 4. Encontra todos os slots visíveis que estão vazios (não possuem nenhum personagem associado por cid)
    const emptySlots: number[] = []
    slots.forEach((currentSlot) => {
      const char = characters.find((candidate) => candidate.cid === currentSlot)
      if (!char) {
        emptySlots.push(currentSlot)
      }
    })

    // 5. Se este slot atual for um dos vazios, distribui os personagens não mapeados na ordem em que aparecem
    const emptyIndex = emptySlots.indexOf(slot)
    if (emptyIndex !== -1 && emptyIndex < unmappedCharacters.length) {
      return unmappedCharacters[emptyIndex]
    }

    return undefined
  }

  const getInitials = (firstname: string, lastname: string) => `${firstname[0]}${lastname[0]}`.toUpperCase()

  return (
    <div className="card-premium rounded-3xl p-5 space-y-4 shadow-2xl animate-left-panel">
      {/* Header do Painel */}
      <div className="flex items-center justify-between border-b border-white/5 pb-4">
        <div className="space-y-1">
          <h2 className="text-xs uppercase tracking-[0.2em] font-bold text-primary text-glow-primary flex items-center gap-2">
            <Users className="h-4 w-4" />
            {locales.characters?.title || 'PERSONAGENS'}
          </h2>
          <p className="text-[11px] text-muted-foreground uppercase tracking-wider">
            {characters.length} / {maxSlots} {locales.commands?.slots?.params?.amount || 'Slots Ativos'}
          </p>
        </div>
      </div>

      {/* Lista de Slots */}
      <div className="space-y-3">
        {slots.map((slot) => {
          const character = getCharacterForSlot(slot)
          const isSelected = selectedCharacter?.citizenid === character?.citizenid
          const isEmpty = !character

          return (
            <div
              key={`slot-${slot}-${character?.citizenid || 'empty'}`}
              className={cn(
                'group relative flex items-center justify-between cursor-pointer overflow-hidden rounded-2xl border p-3.5 transition-all duration-300',
                isSelected
                  ? 'border-primary bg-[#0c0d12]/95 glow-primary'
                  : 'border-white/5 bg-[#06060a]/65 hover:border-primary/40 hover:bg-[#0c0d12]/80',
                isEmpty && 'border-dashed border-white/10 hover:border-primary/30',
              )}
              onClick={() => {
                if (character) {
                  onSelect(character)
                } else {
                  onCreate(slot)
                }
              }}
            >
              {/* Barra lateral verde neon para o item selecionado */}
              {isSelected && (
                <div className="absolute inset-y-0 left-0 w-1 bg-primary" />
              )}

              {/* Ponto indicador pulsante verde neon se selecionado */}
              {isSelected && !isEmpty && (
                <span className="absolute top-2 right-2 flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
                </span>
              )}

              <div className="flex items-center gap-3.5 flex-1 min-w-0">
                <div className="relative shrink-0">
                  {loadingPhotos && character ? (
                    <Skeleton className="h-12 w-12 rounded-xl" />
                  ) : (
                    <Avatar
                      className={cn(
                        'h-12 w-12 rounded-xl border border-white/5 transition-transform duration-300 group-hover:scale-105',
                        isEmpty ? 'bg-transparent' : 'bg-zinc-950',
                      )}
                    >
                      {character && characterPhotos[character.citizenid] ? (
                        <AvatarImage
                          src={characterPhotos[character.citizenid]}
                          alt={`${character.charinfo.firstname} ${character.charinfo.lastname}`}
                          className="object-cover"
                        />
                      ) : null}
                      <AvatarFallback className="rounded-xl bg-zinc-900/60 text-sm font-semibold text-zinc-400">
                        {character ? getInitials(character.charinfo.firstname, character.charinfo.lastname) : <Plus className="h-5 w-5 text-zinc-500 group-hover:text-primary transition-colors" />}
                      </AvatarFallback>
                    </Avatar>
                  )}

                  {character && !loadingPhotos && (
                    <span className="absolute -bottom-1 -right-1 flex h-4.5 w-4.5 items-center justify-center rounded-full border border-zinc-950 bg-primary text-[8px] text-primary-foreground">
                      <Sparkles className="h-2.5 w-2.5" />
                    </span>
                  )}
                </div>

                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <h3 className="truncate text-[13px] font-semibold text-foreground tracking-wide group-hover:text-primary transition-colors">
                        {character
                          ? `${character.charinfo.firstname} ${character.charinfo.lastname}`
                          : locales.characters?.slot_label?.replace('%{slot}', String(slot)) || `Slot ${slot}`}
                      </h3>
                      {character ? (
                        <p className="mt-0.5 truncate text-[9px] uppercase tracking-wider text-muted-foreground">
                          {locales.characters?.id_prefix || 'ID'} {character.citizenid}
                        </p>
                      ) : (
                        <p className="text-[10px] text-zinc-500 group-hover:text-zinc-400 transition-colors">
                          {locales.characters?.create_character || 'Criar Novo Personagem'}
                        </p>
                      )}
                    </div>
                  </div>

                  {character && (
                    <div className="flex flex-wrap items-center gap-1.5 mt-2">
                      <span className="flex items-center gap-1 rounded-lg bg-[#111218]/90 px-2 py-0.5 text-[10px] font-medium text-zinc-300 border border-white/5">
                        <Briefcase className="h-3 w-3 text-primary shrink-0" />
                        <span className="truncate max-w-[90px]">
                          {character.job?.label || locales.characters?.unemployed || 'Desempregado'}
                        </span>
                      </span>
                      <span className="flex items-center gap-1 rounded-lg bg-[#111218]/90 px-2 py-0.5 text-[10px] font-medium text-zinc-300 border border-white/5">
                        <Wallet className="h-3 w-3 text-primary shrink-0" />
                        <span>
                          ${(character.money?.cash || 0).toLocaleString()}
                        </span>
                      </span>
                    </div>
                  )}
                </div>
              </div>

              <div className="ml-3 shrink-0">
                {isEmpty ? (
                  <Plus className="h-4 w-4 text-zinc-600 group-hover:text-primary transition-colors" />
                ) : (
                  <ChevronRight className={cn(
                    'h-4 w-4 text-zinc-600 transition-all duration-300 group-hover:translate-x-0.5 group-hover:text-primary',
                    isSelected && 'text-primary translate-x-0.5',
                  )} />
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

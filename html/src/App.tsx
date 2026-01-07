import { useState, useEffect } from 'react'
import { CharacterList } from './components/CharacterList'
import { CharacterCreation } from './components/CharacterCreation'
import { DeleteConfirmDialog } from './components/DeleteConfirmDialog'
import { GlitchName } from './components/GlitchName'
import { MusicPlayer } from './components/MusicPlayer'
import { formatNumber } from './utils/formatNumber'
import { Avatar, AvatarImage, AvatarFallback } from './components/ui/avatar'
import { Badge } from './components/ui/badge'
import { Briefcase, Wallet, Building2, Calendar, User, Trash2, Play, Shield, Crown } from 'lucide-react'
import { cn } from './lib/utils'

declare function GetParentResourceName(): string

export interface Character {
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
  money: {
    bank: number
    cash: number
  }
  job: {
    name?: string
    label: string
    grade: number | { name: string }
  }
  gang: {
    label: string
    grade: { name: string }
  }
  cid?: number
  photo?: string
}

interface Theme {
  name: string
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

interface MusicConfig {
  enabled: boolean
  url: string
  volume: number
  loop: boolean
  autoplay: boolean
}

function App() {
  const [isOpen, setIsOpen] = useState(false)
  const [characters, setCharacters] = useState<Character[]>([])
  const [maxSlots, setMaxSlots] = useState(3)
  const [selectedCharacter, setSelectedCharacter] = useState<Character | null>(null)
  const [showCreation, setShowCreation] = useState(false)
  const [creatingSlot, setCreatingSlot] = useState<number | null>(null)
  const [theme, setTheme] = useState<Theme | null>(null)
  const [music, setMusic] = useState<MusicConfig | null>(null)
  const [showDeleteDialog, setShowDeleteDialog] = useState(false)
  const [characterToDelete, setCharacterToDelete] = useState<Character | null>(null)
  const [selectedCharacterPhoto, setSelectedCharacterPhoto] = useState<string | null>(null)

  useEffect(() => {
    console.log('[mri_Qmultichar] App montado, aguardando mensagens...')
    
    const handleMessage = (event: MessageEvent) => {
      const data = event.data
      console.log('[mri_Qmultichar] Mensagem recebida:', data)
      
      if (data && data.action === 'open') {
        console.log('[mri_Qmultichar] Abrindo NUI...')
        setIsOpen(true)
        loadCharacters()
      } else if (data && data.action === 'close') {
        console.log('[mri_Qmultichar] Fechando NUI...')
        setIsOpen(false)
        setSelectedCharacter(null)
        setShowCreation(false)
      } else if (data && data.action === 'refreshCharacters') {
        console.log('[mri_Qmultichar] Recarregando personagens...')
        // Pequeno delay para garantir que o servidor processou a deleção
        setTimeout(() => {
          loadCharacters()
        }, 300)
      }
    }

    window.addEventListener('message', handleMessage)
    
    // Debug: verificar se a mensagem está chegando após 2 segundos
    setTimeout(() => {
      console.log('[mri_Qmultichar] Estado após 2s - isOpen:', isOpen)
    }, 2000)
    
    return () => window.removeEventListener('message', handleMessage)
  }, [])

  const loadCharacters = () => {
    console.log('[mri_Qmultichar] Carregando personagens...')
    fetch(`https://${GetParentResourceName()}/getCharacters`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    })
      .then((res) => {
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`)
        }
        return res.json()
      })
      .then((data) => {
        console.log('[mri_Qmultichar] Dados recebidos:', data)
        if (data && data.success) {
          setCharacters(data.characters || [])
          setMaxSlots(data.amount || 3)
          if (data.theme) {
            setTheme(data.theme)
          }
          if (data.music) {
            setMusic(data.music)
          }
          // Selecionar primeiro personagem se existir
          if (data.characters && data.characters.length > 0) {
            setSelectedCharacter(data.characters[0])
            // Atualizar preview
            const jobName = data.characters[0].job?.name || (data.characters[0].job?.label ? data.characters[0].job.label.toLowerCase().replace(/\s+/g, '') : 'unemployed')
            fetch(`https://${GetParentResourceName()}/getPreviewData`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ 
                citizenid: data.characters[0].citizenid,
                job: jobName
              }),
            }).catch(console.error)
          }
        } else {
          console.error('[mri_Qmultichar] Erro ao carregar personagens:', data)
          setCharacters([])
          setMaxSlots(3)
        }
      })
      .catch((err) => {
        console.error('[mri_Qmultichar] Erro ao carregar personagens:', err)
        setCharacters([])
        setMaxSlots(3)
      })
  }

  const handleLoadCharacter = (citizenid: string) => {
    fetch(`https://${GetParentResourceName()}/loadCharacter`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ citizenid }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.success) {
          setIsOpen(false)
        }
      })
      .catch((err) => console.error('Erro ao carregar personagem:', err))
  }

  const handleDeleteCharacter = (citizenid: string) => {
    const character = characters.find(c => c.citizenid === citizenid)
    setCharacterToDelete(character || null)
    setShowDeleteDialog(true)
  }

  const confirmDelete = () => {
    if (!characterToDelete) return
    
    fetch(`https://${GetParentResourceName()}/deleteCharacter`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ citizenid: characterToDelete.citizenid }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.success) {
          // Aguardar um pouco antes de recarregar para garantir que o servidor processou
          setTimeout(() => {
            loadCharacters()
            setSelectedCharacter(null)
            setShowDeleteDialog(false)
            setCharacterToDelete(null)
          }, 500)
        }
      })
      .catch((err) => console.error('Erro ao deletar personagem:', err))
  }

  const handleCreateCharacter = (slot: number) => {
    setCreatingSlot(slot)
    setShowCreation(true)
    setSelectedCharacter(null)
  }

  const handleCharacterCreated = () => {
    setShowCreation(false)
    setCreatingSlot(null)
    loadCharacters()
  }

  const handleCharacterSelect = (character: Character) => {
    setSelectedCharacter(character)
    setShowCreation(false)
    
    // Carregar foto do personagem
    fetch(`https://${GetParentResourceName()}/getCharacterPhoto`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ citizenid: character.citizenid }),
    })
      .then(res => res.json())
      .then(data => {
        if (data.success && data.photo) {
          setSelectedCharacterPhoto(data.photo)
        } else {
          setSelectedCharacterPhoto(null)
        }
      })
      .catch(() => setSelectedCharacterPhoto(null))
    
    // Enviar evento para atualizar preview
    const jobName = character.job?.name || (character.job?.label ? character.job.label.toLowerCase().replace(/\s+/g, '') : 'unemployed')
    fetch(`https://${GetParentResourceName()}/getPreviewData`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ 
        citizenid: character.citizenid,
        job: jobName
      }),
    }).catch((err) => console.error('Erro ao obter preview:', err))
  }

  if (!isOpen) {
    return null
  }

  if (showCreation) {
    return (
      <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
        <CharacterCreation
          slot={creatingSlot || 1}
          theme={theme}
          onCancel={() => {
            setShowCreation(false)
            setCreatingSlot(null)
          }}
          onSuccess={handleCharacterCreated}
        />
        {/* Player de música fixo na parte inferior */}
        <div style={{ pointerEvents: 'auto', position: 'fixed', bottom: 0, left: 0, right: 0, zIndex: 10001, display: 'flex', justifyContent: 'center', paddingBottom: '20px' }}>
          <MusicPlayer music={music || undefined} theme={theme || undefined} />
        </div>
      </div>
    )
  }

  return (
    <div className="fixed inset-0" style={{ background: 'transparent', pointerEvents: 'none' }}>
      <div className="h-full flex items-center justify-center gap-6" style={{ pointerEvents: 'none', background: 'transparent', padding: '2rem' }}>
        {/* Left Panel - My Characters */}
        <div 
          className={cn(
            "w-80 rounded-2xl overflow-hidden",
            "animate-in slide-in-from-left-4 fade-in duration-500"
          )}
          style={{ 
            pointerEvents: 'auto', 
            maxHeight: '90vh',
            backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
            border: `1px solid ${theme?.colors.border || 'rgba(51, 65, 85, 0.5)'}`,
            boxShadow: `0 20px 60px rgba(0, 0, 0, 0.3), 0 0 40px ${theme?.colors.accent?.primary || '#3B82F6'}10`,
          }}
        >
          <div 
            className="p-6 border-b relative overflow-hidden"
            style={{ borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)' }}
          >
            <div 
              className="absolute inset-0 opacity-10"
              style={{
                background: `linear-gradient(135deg, ${theme?.colors.accent?.primary || '#3B82F6'} 0%, ${theme?.colors.accent?.secondary || '#8B5CF6'} 100%)`,
              }}
            />
            <div className="relative z-10">
              <h2 
                className="text-2xl font-bold mb-2 flex items-center gap-2"
                style={{ color: theme?.colors.text.primary || '#F8FAFC' }}
              >
                <User className="w-6 h-6" />
                My Characters
              </h2>
              <div className="flex items-center gap-2">
                <Badge 
                  variant="outline"
                  style={{
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                    color: theme?.colors.text.secondary || '#CBD5E1',
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                  }}
                >
                  {characters.length} / {maxSlots} slots
                </Badge>
              </div>
            </div>
          </div>
          <div className="overflow-y-auto" style={{ maxHeight: 'calc(90vh - 100px)', scrollbarWidth: 'thin' }}>
            <CharacterList
              characters={characters}
              maxSlots={maxSlots}
              selectedCharacter={selectedCharacter}
              onSelect={handleCharacterSelect}
              onCreate={handleCreateCharacter}
              theme={theme}
            />
          </div>
        </div>

        {/* Center - Character Preview - ÁREA COMPLETAMENTE TRANSPARENTE PARA MOSTRAR O JOGO */}
        <div 
          className="flex-1 preview-area" 
          style={{ 
            background: 'transparent !important', 
            pointerEvents: 'none',
            position: 'relative',
            minHeight: '600px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'flex-start',
          }}
        >
          {/* Efeito de nome com glitch acima do preview */}
          {selectedCharacter && (
            <div style={{ 
              position: 'absolute',
              top: '20px',
              left: '50%',
              transform: 'translateX(-50%)',
              zIndex: 1000,
              width: '100%',
              pointerEvents: 'none',
            }}>
              <GlitchName
                name={`${selectedCharacter.charinfo.firstname} ${selectedCharacter.charinfo.lastname}`}
                theme={theme || undefined}
              />
            </div>
          )}
          
          {/* Esta área é completamente transparente - o jogo renderiza o preview do personagem aqui */}
        </div>

        {/* Right Panel - Character Info */}
        <div 
          className={cn(
            "w-96 rounded-2xl shadow-2xl",
            "animate-in slide-in-from-right-4 fade-in duration-500"
          )}
          style={{ 
            pointerEvents: 'auto', 
            maxHeight: '90vh',
            backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
            border: `1px solid ${theme?.colors.border || 'rgba(51, 65, 85, 0.5)'}`,
            boxShadow: `0 20px 60px rgba(0, 0, 0, 0.3), 0 0 40px ${theme?.colors.accent?.primary || '#3B82F6'}10`,
          }}
        >
          <div 
            className="p-6 border-b relative overflow-hidden"
            style={{ borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)' }}
          >
            <div 
              className="absolute inset-0 opacity-10"
              style={{
                background: `linear-gradient(135deg, ${theme?.colors.accent?.primary || '#3B82F6'} 0%, ${theme?.colors.accent?.secondary || '#8B5CF6'} 100%)`,
              }}
            />
            <h2 
              className="text-2xl font-bold relative z-10 flex items-center gap-2"
              style={{ color: theme?.colors.text.primary || '#F8FAFC' }}
            >
              <User className="w-6 h-6" />
              Character Info
            </h2>
          </div>
          <div className="overflow-y-auto" style={{ maxHeight: 'calc(90vh - 100px)' }}>
            {selectedCharacter ? (
            <div className="p-6 space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
              {/* Avatar Header */}
              <div className="flex items-center gap-4 pb-4 border-b" style={{ borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)' }}>
                <Avatar className="w-20 h-20 border-4 shadow-xl bg-gradient-to-br from-blue-500 via-purple-500 to-pink-500">
                  {selectedCharacterPhoto ? (
                    <AvatarImage 
                      src={selectedCharacterPhoto} 
                      alt={`${selectedCharacter.charinfo.firstname} ${selectedCharacter.charinfo.lastname}`}
                      className="object-cover"
                    />
                  ) : null}
                  <AvatarFallback className="text-2xl font-bold text-white">
                    {selectedCharacter.charinfo.firstname[0]}{selectedCharacter.charinfo.lastname[0]}
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1">
                  <h3 
                    className="text-xl font-bold mb-1 bg-gradient-to-r bg-clip-text text-transparent"
                    style={{
                      backgroundImage: `linear-gradient(to right, ${theme?.colors.accent?.primary || '#3B82F6'}, ${theme?.colors.accent?.secondary || '#8B5CF6'})`,
                    }}
                  >
                    {selectedCharacter.charinfo.firstname} {selectedCharacter.charinfo.lastname}
                  </h3>
                  <Badge 
                    variant="outline"
                    className="mt-1"
                    style={{
                      borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                      color: theme?.colors.text.secondary || '#CBD5E1',
                      backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    }}
                  >
                    <Shield className="w-3 h-3 mr-1" />
                    {selectedCharacter.citizenid}
                  </Badge>
                </div>
              </div>

              {/* Job & Grade */}
              <div className="grid grid-cols-2 gap-3">
                <div 
                  className="relative p-4 rounded-xl border transition-all hover:scale-105 group overflow-hidden"
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  }}
                >
                  <div 
                    className="absolute inset-0 opacity-0 group-hover:opacity-10 transition-opacity"
                    style={{
                      background: `linear-gradient(135deg, ${theme?.colors.accent?.primary || '#3B82F6'}, ${theme?.colors.accent?.secondary || '#8B5CF6'})`,
                    }}
                  />
                  <div className="relative z-10">
                    <div className="flex items-center gap-2 mb-2">
                      <Briefcase className="w-4 h-4" style={{ color: theme?.colors.accent?.primary || '#3B82F6' }} />
                      <span className="text-xs uppercase tracking-wider opacity-70" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                        Job
                      </span>
                    </div>
                    <p className="font-bold text-lg" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
                      {selectedCharacter.job?.label || 'UNEMPLOYED'}
                    </p>
                  </div>
                </div>
                <div 
                  className="relative p-4 rounded-xl border transition-all hover:scale-105 group overflow-hidden"
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  }}
                >
                  <div 
                    className="absolute inset-0 opacity-0 group-hover:opacity-10 transition-opacity"
                    style={{
                      background: `linear-gradient(135deg, ${theme?.colors.accent?.primary || '#3B82F6'}, ${theme?.colors.accent?.secondary || '#8B5CF6'})`,
                    }}
                  />
                  <div className="relative z-10">
                    <div className="flex items-center gap-2 mb-2">
                      <Crown className="w-4 h-4" style={{ color: '#FBBF24' }} />
                      <span className="text-xs uppercase tracking-wider opacity-70" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                        Grade
                      </span>
                    </div>
                    <p className="font-bold text-lg" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
                      {typeof selectedCharacter.job?.grade === 'object' 
                        ? selectedCharacter.job.grade.name 
                        : selectedCharacter.job?.grade || '0'}
                    </p>
                  </div>
                </div>
              </div>

              {/* Money Cards */}
              <div className="grid grid-cols-2 gap-3">
                <div 
                  className="relative p-4 rounded-xl border overflow-hidden group transition-all hover:scale-105"
                  style={{
                    background: 'linear-gradient(135deg, rgba(34, 197, 94, 0.15) 0%, rgba(16, 185, 129, 0.15) 100%)',
                    borderColor: 'rgba(34, 197, 94, 0.3)',
                  }}
                >
                  <div className="flex items-center gap-2 mb-2">
                    <Wallet className="w-4 h-4 text-green-400" />
                    <span className="text-xs uppercase tracking-wider opacity-70 text-green-300">Cash</span>
                  </div>
                  <p className="font-bold text-xl text-green-300">
                    ${formatNumber(selectedCharacter.money?.cash || 0)}
                  </p>
                </div>
                <div 
                  className="relative p-4 rounded-xl border overflow-hidden group transition-all hover:scale-105"
                  style={{
                    background: 'linear-gradient(135deg, rgba(59, 130, 246, 0.15) 0%, rgba(37, 99, 235, 0.15) 100%)',
                    borderColor: 'rgba(59, 130, 246, 0.3)',
                  }}
                >
                  <div className="flex items-center gap-2 mb-2">
                    <Building2 className="w-4 h-4 text-blue-400" />
                    <span className="text-xs uppercase tracking-wider opacity-70 text-blue-300">Bank</span>
                  </div>
                  <p className="font-bold text-xl text-blue-300">
                    ${formatNumber(selectedCharacter.money?.bank || 0)}
                  </p>
                </div>
              </div>

              {/* Additional Info */}
              <div className="grid grid-cols-2 gap-3">
                <div 
                  className="p-3 rounded-lg border"
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.03)',
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  }}
                >
                  <span className="text-xs uppercase tracking-wider opacity-70 block mb-1" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                    Gender
                  </span>
                  <p className="font-semibold" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
                    {selectedCharacter.charinfo.gender === 0 ? 'Male' : 'Female'}
                  </p>
                </div>
                <div 
                  className="p-3 rounded-lg border"
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.03)',
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  }}
                >
                  <div className="flex items-center gap-1 mb-1">
                    <Calendar className="w-3 h-3 opacity-70" style={{ color: theme?.colors.text.muted || '#94A3B8' }} />
                    <span className="text-xs uppercase tracking-wider opacity-70" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                      Birthdate
                    </span>
                  </div>
                  <p className="font-semibold" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
                    {selectedCharacter.charinfo.birthdate || 'N/A'}
                  </p>
                </div>
              </div>
              
              {/* Action Buttons */}
              <div className="pt-4 space-y-3">
                <button
                  onClick={() => handleLoadCharacter(selectedCharacter.citizenid)}
                  className={cn(
                    "w-full font-semibold py-4 px-6 rounded-xl transition-all duration-300",
                    "hover:scale-[1.02] hover:shadow-xl flex items-center justify-center gap-2",
                    "relative overflow-hidden group"
                  )}
                  style={{ 
                    background: `linear-gradient(135deg, ${theme?.colors.button.primary || '#3B82F6'}, ${theme?.colors.button.primaryHover || '#2563EB'})`,
                    color: '#FFFFFF',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'scale(1.02)'
                    e.currentTarget.style.boxShadow = `0 10px 40px ${theme?.colors.button.primary || '#3B82F6'}40`
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'scale(1)'
                    e.currentTarget.style.boxShadow = 'none'
                  }}
                >
                  <Play className="w-5 h-5" />
                  Choose Character
                </button>
                <button
                  onClick={() => handleDeleteCharacter(selectedCharacter.citizenid)}
                  className={cn(
                    "w-full font-semibold py-4 px-6 rounded-xl transition-all duration-300",
                    "hover:scale-[1.02] hover:shadow-xl flex items-center justify-center gap-2",
                    "relative overflow-hidden"
                  )}
                  style={{ 
                    background: `linear-gradient(135deg, ${theme?.colors.button.danger || '#EF4444'}, ${theme?.colors.button.dangerHover || '#DC2626'})`,
                    color: '#FFFFFF',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'scale(1.02)'
                    e.currentTarget.style.boxShadow = `0 10px 40px ${theme?.colors.button.danger || '#EF4444'}40`
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'scale(1)'
                    e.currentTarget.style.boxShadow = 'none'
                  }}
                >
                  <Trash2 className="w-5 h-5" />
                  Delete Character
                </button>
              </div>
            </div>
          ) : (
            <div className="p-6 text-center animate-in fade-in duration-500">
              <div 
                className="rounded-xl p-12 border"
                style={{
                  backgroundColor: 'rgba(255, 255, 255, 0.03)',
                  borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                }}
              >
                <User className="w-16 h-16 mx-auto mb-4 opacity-30" style={{ color: theme?.colors.text.muted || '#94A3B8' }} />
                <p className="text-lg font-semibold mb-2" style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}>
                  Select a character
                </p>
                <p className="text-sm opacity-70" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                  or create a new one
                </p>
              </div>
            </div>
            )}
          </div>
        </div>
      </div>

      {/* Player de música fixo na parte inferior */}
      <div style={{ pointerEvents: 'auto', position: 'fixed', bottom: 0, left: 0, right: 0, zIndex: 10000, display: 'flex', justifyContent: 'center', paddingBottom: '20px' }}>
        <MusicPlayer music={music || undefined} theme={theme || undefined} />
      </div>

      {/* Delete Confirmation Dialog */}
      <DeleteConfirmDialog
        open={showDeleteDialog}
        onClose={() => {
          setShowDeleteDialog(false)
          setCharacterToDelete(null)
        }}
        onConfirm={confirmDelete}
        characterName={characterToDelete ? `${characterToDelete.charinfo.firstname} ${characterToDelete.charinfo.lastname}` : undefined}
        theme={theme}
      />
    </div>
  )
}

export default App

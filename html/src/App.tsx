import { useState, useEffect } from 'react'
import { CharacterList } from './components/CharacterList'
import { CharacterCreation } from './components/CharacterCreation'
import { DeleteConfirmDialog } from './components/DeleteConfirmDialog'
import { GlitchName } from './components/GlitchName'
import { formatNumber } from './utils/formatNumber'

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

function App() {
  const [isOpen, setIsOpen] = useState(false)
  const [characters, setCharacters] = useState<Character[]>([])
  const [maxSlots, setMaxSlots] = useState(3)
  const [selectedCharacter, setSelectedCharacter] = useState<Character | null>(null)
  const [showCreation, setShowCreation] = useState(false)
  const [creatingSlot, setCreatingSlot] = useState<number | null>(null)
  const [theme, setTheme] = useState<Theme | null>(null)
  const [showDeleteDialog, setShowDeleteDialog] = useState(false)
  const [characterToDelete, setCharacterToDelete] = useState<Character | null>(null)

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
      </div>
    )
  }

  return (
    <div className="fixed inset-0" style={{ background: 'transparent', pointerEvents: 'none' }}>
      <div className="h-full flex items-center justify-center gap-6" style={{ pointerEvents: 'none', background: 'transparent', padding: '2rem' }}>
        {/* Left Panel - My Characters */}
        <div 
          className="w-80 rounded-2xl overflow-hidden shadow-2xl animate-slide-in" 
          style={{ 
            pointerEvents: 'auto', 
            maxHeight: '90vh',
            backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.9)',
            border: `1px solid ${theme?.colors.border || 'rgba(51, 65, 85, 0.5)'}`,
          }}
        >
          <div className="p-5 border-b" style={{ borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)' }}>
            <h2 className="text-xl font-semibold" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>My Characters</h2>
            <p className="text-sm mt-1" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>{characters.length} / {maxSlots} slots</p>
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
          className="w-96 rounded-2xl shadow-2xl animate-slide-in" 
          style={{ 
            pointerEvents: 'auto', 
            maxHeight: '90vh',
            backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.9)',
            border: `1px solid ${theme?.colors.border || 'rgba(51, 65, 85, 0.5)'}`,
            animationDelay: '0.1s',
          }}
        >
          <div className="p-5 border-b" style={{ borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)' }}>
            <h2 className="text-xl font-semibold" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>Character Info</h2>
          </div>
          <div className="overflow-y-auto" style={{ maxHeight: 'calc(90vh - 100px)' }}>
            {selectedCharacter ? (
            <div className="p-6 space-y-6">
              <div className="space-y-4">
                <div className="bg-white/5 rounded-lg p-4 border border-white/10">
                  <span className="text-gray-400 text-xs uppercase tracking-wider">Name</span>
                  <p className="text-white font-bold text-lg mt-1">
                    {selectedCharacter.charinfo.firstname} {selectedCharacter.charinfo.lastname}
                  </p>
                </div>
                
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-white/5 rounded-lg p-3 border border-white/10">
                    <span className="text-gray-400 text-xs uppercase tracking-wider">Job</span>
                    <p className="text-white font-semibold mt-1">{selectedCharacter.job?.label || 'UNEMPLOYED'}</p>
                  </div>
                  <div className="bg-white/5 rounded-lg p-3 border border-white/10">
                    <span className="text-gray-400 text-xs uppercase tracking-wider">Grade</span>
                    <p className="text-white font-semibold mt-1">
                      {typeof selectedCharacter.job?.grade === 'object' 
                        ? selectedCharacter.job.grade.name 
                        : selectedCharacter.job?.grade || '0'}
                    </p>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-white/5 rounded-lg p-3 border border-white/10">
                    <span className="text-gray-400 text-xs uppercase tracking-wider">Gender</span>
                    <p className="text-white font-semibold mt-1">{selectedCharacter.charinfo.gender === 0 ? 'Male' : 'Female'}</p>
                  </div>
                  <div className="bg-white/5 rounded-lg p-3 border border-white/10">
                    <span className="text-gray-400 text-xs uppercase tracking-wider">Birthdate</span>
                    <p className="text-white font-semibold mt-1">{selectedCharacter.charinfo.birthdate || 'N/A'}</p>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-white/5 rounded-lg p-3 border border-white/10">
                    <span className="text-gray-400 text-xs font-medium">Cash</span>
                    <p className="text-white font-semibold text-base mt-1">${formatNumber(selectedCharacter.money?.cash || 0)}</p>
                  </div>
                  <div className="bg-white/5 rounded-lg p-3 border border-white/10">
                    <span className="text-gray-400 text-xs font-medium">Bank</span>
                    <p className="text-white font-semibold text-base mt-1">${formatNumber(selectedCharacter.money?.bank || 0)}</p>
                  </div>
                </div>
              </div>
              
              <div className="pt-4 space-y-3">
                <button
                  onClick={() => handleLoadCharacter(selectedCharacter.citizenid)}
                  className="w-full text-white font-semibold py-3 px-6 rounded-xl transition-all hover:scale-[1.02]"
                  style={{ 
                    backgroundColor: theme?.colors.button.primary || '#3B82F6',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = theme?.colors.button.primaryHover || '#2563EB'
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = theme?.colors.button.primary || '#3B82F6'
                  }}
                >
                  Choose Character
                </button>
                <button
                  onClick={() => handleDeleteCharacter(selectedCharacter.citizenid)}
                  className="w-full text-white font-semibold py-3 px-6 rounded-xl transition-all hover:scale-[1.02]"
                  style={{ 
                    backgroundColor: theme?.colors.button.danger || '#EF4444',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = theme?.colors.button.dangerHover || '#DC2626'
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = theme?.colors.button.danger || '#EF4444'
                  }}
                >
                  Delete Character
                </button>
              </div>
            </div>
          ) : (
            <div className="p-6 text-center">
              <div className="bg-white/5 rounded-lg p-8 border border-white/10">
                <p className="text-gray-400 text-lg">Select a character</p>
                <p className="text-gray-500 text-sm mt-2">or create a new one</p>
              </div>
            </div>
            )}
          </div>
        </div>
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

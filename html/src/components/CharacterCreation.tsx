import { useMemo, useState } from 'react'
import {
  MriButton,
  MriCard,
  MriCardContent,
  MriCardHeader,
  MriDatePicker,
  MriInput,
  MriModal,
  MriSectionHeader,
  MriSelect,
} from '@mriqbox/ui-kit'
import { ArrowLeft, ShieldPlus, X } from 'lucide-react'
import { nationalities } from '../data/nationalities'
import type { UiTheme } from '../lib/mriTheme'

declare function GetParentResourceName(): string

interface CharacterCreationProps {
  slot: number
  theme: UiTheme | null
  onCancel: () => void
  onSuccess: () => void
  locales?: any
}

const MIN_BIRTHDATE = new Date(1900, 0, 1)
const MAX_BIRTHDATE = new Date(2006, 11, 31)

function formatBirthdate(date: Date) {
  const day = String(date.getDate()).padStart(2, '0')
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const year = date.getFullYear()
  return `${day}/${month}/${year}`
}

export function CharacterCreation({
  slot,
  theme: _theme,
  onCancel,
  onSuccess,
  locales = {},
}: CharacterCreationProps) {
  const [formData, setFormData] = useState({
    firstname: '',
    lastname: '',
    nationality: locales.character_creation?.default_nationality || 'Brasileiro',
    gender: '0',
  })
  const [birthdate, setBirthdate] = useState<Date | null>(null)
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const genderOptions = useMemo(
    () => [
      { label: locales.character_creation?.male || 'Masculino', value: '0' },
      { label: locales.character_creation?.female || 'Feminino', value: '1' },
    ],
    [locales.character_creation?.female, locales.character_creation?.male],
  )

  const nationalityOptions = useMemo(
    () => nationalities.map((value) => ({ label: value, value })),
    [],
  )

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()

    if (!birthdate) {
      setErrorMessage(locales.character_creation?.select_birthdate || 'Por favor, selecione uma data de nascimento')
      return
    }

    setLoading(true)

    fetch(`https://${GetParentResourceName()}/createCharacter`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        characterData: {
          firstname: formData.firstname,
          lastname: formData.lastname,
          nationality: formData.nationality,
          gender: Number.parseInt(formData.gender, 10),
          birthdate: formatBirthdate(birthdate),
          cid: slot,
        },
      }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.success) {
          onSuccess()
        } else {
          setErrorMessage(`${locales.character_creation?.create_error || 'Erro ao criar personagem:'} ${data.message || 'Erro desconhecido'}`)
        }
      })
      .catch((err) => {
        console.error('Erro ao criar personagem:', err)
        setErrorMessage(locales.character_creation?.generic_error || 'Erro ao criar personagem')
      })
      .finally(() => {
        setLoading(false)
      })
  }

  return (
    <>
      <div className="w-full max-w-3xl px-4">
        <MriCard className="rounded-3xl border border-border/80 bg-card/95 shadow-2xl shadow-black/30">
          <MriCardHeader className="space-y-4 border-b border-border/70 p-6">
            <div className="flex items-center justify-between gap-4">
              <MriButton
                variant="ghost"
                size="icon"
                className="h-11 w-11 rounded-2xl"
                onClick={onCancel}
              >
                <ArrowLeft className="h-5 w-5" />
              </MriButton>

              <div className="flex-1 text-center">
                <MriSectionHeader
                  icon={ShieldPlus}
                  title={locales.character_creation?.title || 'Criação de Personagem'}
                  className="!mb-0 justify-center"
                />
                <p className="mt-2 text-sm text-muted-foreground">
                  {locales.character_creation?.description || 'Preencha os dados iniciais para criar sua identidade.'}
                </p>
              </div>

              <div className="flex h-11 min-w-[2.75rem] items-center justify-center rounded-2xl border border-primary/30 bg-primary/10 px-3 text-sm font-semibold text-primary">
                {slot}
              </div>
            </div>
          </MriCardHeader>

          <MriCardContent className="p-6">
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <label className="text-sm font-medium text-foreground">
                    {locales.character_creation?.first_name || 'Nome'}
                  </label>
                  <MriInput
                    required
                    value={formData.firstname}
                    onChange={(event) => setFormData((prev) => ({ ...prev, firstname: event.target.value }))}
                    placeholder={locales.character_creation?.first_name_placeholder || 'João'}
                  />
                </div>

                <div className="space-y-2">
                  <label className="text-sm font-medium text-foreground">
                    {locales.character_creation?.last_name || 'Sobrenome'}
                  </label>
                  <MriInput
                    required
                    value={formData.lastname}
                    onChange={(event) => setFormData((prev) => ({ ...prev, lastname: event.target.value }))}
                    placeholder={locales.character_creation?.last_name_placeholder || 'Silva'}
                  />
                </div>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <label className="text-sm font-medium text-foreground">
                    {locales.character_creation?.nationality || 'Nacionalidade'}
                  </label>
                  <MriSelect
                    portal={false}
                    value={formData.nationality}
                    options={nationalityOptions}
                    onChange={(value) => setFormData((prev) => ({ ...prev, nationality: value }))}
                    placeholder={locales.character_creation?.nationality_placeholder || 'Nacionalidade'}
                    searchPlaceholder={locales.character_creation?.nationality_search || 'Buscar nacionalidade'}
                    emptyMessage={locales.character_creation?.nationality_empty || 'Nenhuma nacionalidade encontrada'}
                  />
                </div>

                <div className="space-y-2">
                  <label className="text-sm font-medium text-foreground">
                    {locales.character_creation?.gender || 'Gênero'}
                  </label>
                  <MriSelect
                    portal={false}
                    value={formData.gender}
                    options={genderOptions}
                    onChange={(value) => setFormData((prev) => ({ ...prev, gender: value }))}
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-foreground">
                  {locales.character_creation?.birthdate || 'Data de Nascimento'}
                </label>
                <MriDatePicker
                  value={birthdate}
                  onChange={(date) => setBirthdate(date ?? null)}
                  placeholder={locales.character_creation?.birthdate_placeholder || 'DD/MM/YYYY'}
                  fromDate={MIN_BIRTHDATE}
                  toDate={MAX_BIRTHDATE}
                />
              </div>

              <div className="grid gap-3 pt-2 md:grid-cols-2">
                <MriButton
                  type="button"
                  variant="outline"
                  className="h-12 rounded-2xl"
                  disabled={loading}
                  onClick={onCancel}
                >
                  {locales.buttons?.cancel || 'Cancelar'}
                </MriButton>

                <MriButton
                  type="submit"
                  className="h-12 rounded-2xl"
                  disabled={loading}
                  isLoading={loading}
                >
                  {loading
                    ? (locales.character_creation?.creating || 'Criando...')
                    : (locales.character_creation?.create || 'Criar')}
                </MriButton>
              </div>
            </form>
          </MriCardContent>
        </MriCard>
      </div>

      {errorMessage && (
        <MriModal
          onClose={() => setErrorMessage(null)}
          hideBlur
          className="w-[min(92vw,28rem)] max-w-[28rem] overflow-hidden rounded-3xl border border-border/80 bg-card p-0 shadow-2xl"
        >
          <div className="flex items-center justify-between border-b border-border/70 px-5 py-4">
            <h3 className="text-lg font-semibold text-foreground">
              {locales.character_creation?.warning_title || 'Aviso'}
            </h3>
            <MriButton
              variant="ghost"
              size="icon"
              className="h-10 w-10 rounded-2xl"
              onClick={() => setErrorMessage(null)}
            >
              <X className="h-4 w-4" />
            </MriButton>
          </div>
          <div className="space-y-4 p-5">
            <p className="text-sm leading-6 text-muted-foreground">{errorMessage}</p>
            <MriButton className="h-11 w-full rounded-2xl" onClick={() => setErrorMessage(null)}>
              OK
            </MriButton>
          </div>
        </MriModal>
      )}
    </>
  )
}

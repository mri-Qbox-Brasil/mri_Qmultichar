import { useMemo, useState, useRef } from 'react'
import {
  MriDatePicker,
  MriModal,
  MriSelect,
} from '@mriqbox/ui-kit'
import { ArrowLeft, ShieldPlus, X } from 'lucide-react'
import { nationalities } from '../data/nationalities'
import { Input } from './ui/input'

declare function GetParentResourceName(): string

interface CharacterCreationProps {
  slot: number
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
  onCancel,
  onSuccess,
  locales = {},
}: CharacterCreationProps) {
  const [formData, setFormData] = useState({
    firstname: '',
    lastname: '',
    nationality: locales.character_creation?.default_nationality ?? '',
    gender: '0',
  })
  const [birthdate, setBirthdate] = useState<Date | null>(null)
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const submitButtonRef = useRef<HTMLButtonElement>(null)

  const genderOptions = useMemo(
    () => [
      { label: locales.character_creation?.male ?? '', value: '0' },
      { label: locales.character_creation?.female ?? '', value: '1' },
    ],
    [locales.character_creation?.female, locales.character_creation?.male],
  )

  const nationalityOptions = useMemo(
    () => nationalities.map((value) => ({ label: value, value })),
    [],
  )

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()

    const submitter = (event.nativeEvent as SubmitEvent).submitter
    if (submitter && submitter !== submitButtonRef.current) {
      return
    }

    if (!birthdate) {
      setErrorMessage(locales.character_creation?.select_birthdate ?? null)
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
          setErrorMessage(`${locales.character_creation?.create_error ?? ''} ${data.message ?? ''}`.trim())
        }
      })
      .catch((err) => {
        console.error('Erro ao criar personagem:', err)
        setErrorMessage(locales.character_creation?.generic_error ?? null)
      })
      .finally(() => {
        setLoading(false)
      })
  }

  return (
    <>
      <div className="w-full max-w-2xl px-4 animate-fade-in">
        <div className="card-premium rounded-3xl border border-white/5 p-6 shadow-2xl space-y-6">
          {/* Cabeçalho */}
          <div className="flex items-center justify-between border-b border-white/5 pb-4">
            <button
              type="button"
              className="h-9 w-9 rounded-xl border border-white/5 bg-[#101116] hover:bg-[#181920] text-zinc-400 hover:text-zinc-200 transition-colors flex items-center justify-center cursor-pointer"
              onClick={onCancel}
              disabled={loading}
            >
              <ArrowLeft className="h-4 w-4" />
            </button>

            <div className="flex-1 text-center px-4">
              <h2 className="text-sm font-bold uppercase tracking-[0.2em] text-primary text-glow-primary flex items-center justify-center gap-2">
                <ShieldPlus className="h-4 w-4 shrink-0" />
                {locales.character_creation?.title ?? 'Criação de Personagem'}
              </h2>
              <p className="mt-1 text-[11px] text-muted-foreground uppercase tracking-wide">
                {locales.character_creation?.description}
              </p>
            </div>

            <div className="flex h-9 min-w-[2.25rem] items-center justify-center rounded-xl border border-primary/20 bg-primary/5 px-3 text-xs font-bold text-primary shadow-sm shadow-primary/10">
              {slot}
            </div>
          </div>

          {/* Formulário */}
          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-1.5">
                <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">
                  {locales.character_creation?.first_name || 'Nome'}
                </label>
                <Input
                  required
                  value={formData.firstname}
                  onChange={(event) => setFormData((prev) => ({ ...prev, firstname: event.target.value }))}
                  placeholder={locales.character_creation?.first_name_placeholder}
                  className="h-10 rounded-xl bg-[#090a0e]/60 border-white/5 focus-visible:ring-primary focus-visible:ring-offset-0 focus:border-primary placeholder:text-zinc-600 text-sm text-white"
                  disabled={loading}
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">
                  {locales.character_creation?.last_name || 'Sobrenome'}
                </label>
                <Input
                  required
                  value={formData.lastname}
                  onChange={(event) => setFormData((prev) => ({ ...prev, lastname: event.target.value }))}
                  placeholder={locales.character_creation?.last_name_placeholder}
                  className="h-10 rounded-xl bg-[#090a0e]/60 border-white/5 focus-visible:ring-primary focus-visible:ring-offset-0 focus:border-primary placeholder:text-zinc-600 text-sm text-white"
                  disabled={loading}
                />
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-1.5">
                <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">
                  {locales.character_creation?.nationality || 'Nacionalidade'}
                </label>
                <MriSelect
                  value={formData.nationality}
                  options={nationalityOptions}
                  onChange={(value) => setFormData((prev) => ({ ...prev, nationality: value }))}
                  placeholder={locales.character_creation?.nationality_placeholder}
                  searchPlaceholder={locales.character_creation?.nationality_search}
                  emptyMessage={locales.character_creation?.nationality_empty}
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">
                  {locales.character_creation?.gender || 'Gênero'}
                </label>
                <MriSelect
                  value={formData.gender}
                  options={genderOptions}
                  onChange={(value) => setFormData((prev) => ({ ...prev, gender: value }))}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">
                {locales.character_creation?.birthdate || 'Data de Nascimento'}
              </label>
              <MriDatePicker
                value={birthdate}
                onChange={(date) => setBirthdate(date ?? null)}
                placeholder={locales.character_creation?.birthdate_placeholder}
                fromDate={MIN_BIRTHDATE}
                toDate={MAX_BIRTHDATE}
              />
            </div>

            {/* Ações */}
            <div className="grid gap-3 pt-2 md:grid-cols-2">
              <button
                type="button"
                className="h-11 rounded-xl border border-white/5 bg-[#101116] hover:bg-[#181920] text-zinc-300 font-semibold text-xs uppercase transition-all duration-300 flex items-center justify-center cursor-pointer"
                disabled={loading}
                onClick={onCancel}
              >
                {locales.buttons?.cancel || 'Cancelar'}
              </button>

              <button
                ref={submitButtonRef}
                type="submit"
                className="h-11 rounded-xl bg-primary text-black font-bold tracking-wide text-xs uppercase shadow-lg shadow-primary/10 transition-all duration-300 glow-primary-hover hover:-translate-y-0.5 active:translate-y-0 flex items-center justify-center cursor-pointer border-none"
                disabled={loading}
              >
                {loading
                  ? locales.character_creation?.creating || 'Criando...'
                  : locales.character_creation?.create || 'Criar'}
              </button>
            </div>
          </form>
        </div>
      </div>

      {errorMessage && (
        <MriModal
          onClose={() => setErrorMessage(null)}
          hideBlur
          className="w-[min(92vw,28rem)] max-w-[28rem] overflow-hidden rounded-3xl border border-white/5 bg-[#090a0e]/95 p-0 shadow-2xl"
        >
          <div className="flex items-center justify-between border-b border-white/5 px-5 py-4">
            <h3 className="text-sm font-bold uppercase tracking-wider text-foreground">
              {locales.character_creation?.warning_title || 'Aviso'}
            </h3>
            <button
              type="button"
              className="h-8 w-8 rounded-lg hover:bg-white/5 text-zinc-400 hover:text-zinc-200 transition-colors flex items-center justify-center cursor-pointer"
              onClick={() => setErrorMessage(null)}
            >
              <X className="h-4 w-4" />
            </button>
          </div>
          <div className="space-y-4 p-5">
            <p className="text-xs leading-5 text-muted-foreground">{errorMessage}</p>
            <button
              className="h-10 w-full rounded-xl bg-primary text-black font-bold text-xs uppercase shadow-md transition-all duration-300 hover:brightness-105 active:translate-y-0 flex items-center justify-center cursor-pointer border-none"
              onClick={() => setErrorMessage(null)}
            >
              OK
            </button>
          </div>
        </MriModal>
      )}
    </>
  )
}

import { type ReactNode, useMemo, useState } from 'react'
import {
  MriButton,
  MriCard,
  MriCardContent,
  MriCardHeader,
  MriInput,
  MriModal,
  MriSectionHeader,
} from '@mriqbox/ui-kit'
import { ArrowLeft, Calendar, ChevronLeft, ChevronRight, Globe, ShieldPlus, User, X } from 'lucide-react'
import { cn } from '@/lib/utils'
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

type PickerModal = 'nationality' | 'gender' | 'birthdate' | null

interface CenteredModalProps {
  title: string
  onClose: () => void
  children: ReactNode
  className?: string
}

interface PickerButtonProps {
  value: string
  placeholder: string
  icon: ReactNode
  onClick: () => void
}

function CenteredModal({ title, onClose, children, className }: CenteredModalProps) {
  return (
    <MriModal
      onClose={onClose}
      hideBlur
      className={cn(
        'w-[min(92vw,32rem)] max-w-[32rem] overflow-hidden rounded-[1.75rem] border border-border/80 bg-card p-0 shadow-2xl',
        className,
      )}
    >
      <div className="flex items-center justify-between border-b border-border/70 px-5 py-4">
        <h3 className="text-lg font-semibold text-foreground">{title}</h3>
        <MriButton variant="ghost" size="icon" className="h-10 w-10 rounded-2xl" onClick={onClose}>
          <X className="h-4 w-4" />
        </MriButton>
      </div>
      <div className="p-5">{children}</div>
    </MriModal>
  )
}

function PickerButton({ value, placeholder, icon, onClick }: PickerButtonProps) {
  const hasValue = value.trim().length > 0

  return (
    <button
      type="button"
      onClick={onClick}
      className="flex h-12 w-full items-center justify-between rounded-2xl border border-border/70 bg-background/45 px-4 text-left transition hover:border-primary/40 hover:bg-background/60"
    >
      <span className={hasValue ? 'text-sm font-medium text-foreground' : 'text-sm text-muted-foreground'}>
        {hasValue ? value : placeholder}
      </span>
      <span className="text-muted-foreground">{icon}</span>
    </button>
  )
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
    nationality: 'Brasileiro',
    gender: '0',
    birthdate: '',
  })
  const [loading, setLoading] = useState(false)
  const [activeModal, setActiveModal] = useState<PickerModal>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [nationalitySearch, setNationalitySearch] = useState('')

  const minYear = 1900
  const maxYear = 2006
  const minDate = new Date(minYear, 0, 1)
  const maxDate = new Date(maxYear, 11, 31)

  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth() + 1)
  const [currentYear, setCurrentYear] = useState(maxYear)
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)

  const months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ]

  const weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

  const genderOptions = useMemo(
    () => [
      { label: locales.character_creation?.male || 'Masculino', value: '0' },
      { label: locales.character_creation?.female || 'Feminino', value: '1' },
    ],
    [locales.character_creation?.female, locales.character_creation?.male],
  )

  const selectedGenderLabel = useMemo(
    () => genderOptions.find((option) => option.value === formData.gender)?.label || genderOptions[0].label,
    [formData.gender, genderOptions],
  )

  const filteredNationalities = useMemo(() => {
    const query = nationalitySearch.trim().toLowerCase()
    if (!query) return nationalities
    return nationalities.filter((nationality) => nationality.toLowerCase().includes(query))
  }, [nationalitySearch])

  const getDaysInMonth = (month: number, year: number) => new Date(year, month, 0).getDate()
  const getFirstDayOfMonth = (month: number, year: number) => new Date(year, month - 1, 1).getDay()

  const isDateDisabled = (day: number, month: number, year: number) => {
    const date = new Date(year, month - 1, day)
    return date < minDate || date > maxDate
  }

  const openError = (message: string) => {
    setErrorMessage(message)
  }

  const closeModal = () => {
    setActiveModal(null)
    setNationalitySearch('')
  }

  const handleDateClick = (day: number) => {
    if (isDateDisabled(day, currentMonth, currentYear)) return

    const date = new Date(currentYear, currentMonth - 1, day)
    setSelectedDate(date)

    const formattedDate = `${String(day).padStart(2, '0')}/${String(currentMonth).padStart(2, '0')}/${currentYear}`
    setFormData((prev) => ({ ...prev, birthdate: formattedDate }))
    setActiveModal(null)
  }

  const handlePrevMonth = () => {
    if (currentMonth === 1) {
      if (currentYear > minYear) {
        setCurrentMonth(12)
        setCurrentYear((prev) => prev - 1)
      }
    } else {
      setCurrentMonth((prev) => prev - 1)
    }
  }

  const handleNextMonth = () => {
    if (currentMonth === 12) {
      if (currentYear < maxYear) {
        setCurrentMonth(1)
        setCurrentYear((prev) => prev + 1)
      }
    } else {
      setCurrentMonth((prev) => prev + 1)
    }
  }

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()

    if (!formData.birthdate) {
      openError(locales.character_creation?.select_birthdate || 'Por favor, selecione uma data de nascimento')
      return
    }

    setLoading(true)

    fetch(`https://${GetParentResourceName()}/createCharacter`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        characterData: {
          firstname: formData.firstname,
          lastname: formData.lastname,
          nationality: formData.nationality,
          gender: Number.parseInt(formData.gender, 10),
          birthdate: formData.birthdate,
          cid: slot,
        },
      }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.success) {
          onSuccess()
        } else {
          openError(`${locales.character_creation?.create_error || 'Erro ao criar personagem:'} ${data.message || 'Erro desconhecido'}`)
        }
      })
      .catch((err) => {
        console.error('Erro ao criar personagem:', err)
        openError(locales.character_creation?.generic_error || 'Erro ao criar personagem')
      })
      .finally(() => {
        setLoading(false)
      })
  }

  return (
    <>
      <div className="w-full max-w-3xl px-4">
        <MriCard className="rounded-[2rem] border border-border/80 bg-card/95 shadow-2xl shadow-black/30">
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
                  title={locales.character_creation?.title || `Criação de Personagem`}
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
                  <PickerButton
                    value={formData.nationality}
                    placeholder={locales.character_creation?.nationality_placeholder || 'Nacionalidade'}
                    icon={<Globe className="h-4 w-4" />}
                    onClick={() => setActiveModal('nationality')}
                  />
                </div>

                <div className="space-y-2">
                  <label className="text-sm font-medium text-foreground">
                    {locales.character_creation?.gender || 'Gênero'}
                  </label>
                  <PickerButton
                    value={selectedGenderLabel}
                    placeholder={locales.character_creation?.gender || 'Gênero'}
                    icon={<User className="h-4 w-4" />}
                    onClick={() => setActiveModal('gender')}
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-foreground">
                  {locales.character_creation?.birthdate || 'Data de Nascimento'}
                </label>
                <PickerButton
                  value={formData.birthdate}
                  placeholder={locales.character_creation?.birthdate_placeholder || 'DD/MM/YYYY'}
                  icon={<Calendar className="h-4 w-4" />}
                  onClick={() => setActiveModal('birthdate')}
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

      {activeModal === 'gender' && (
        <CenteredModal title={locales.character_creation?.gender || 'Gênero'} onClose={closeModal} className="w-[min(92vw,22rem)] max-w-[22rem]">
          <div className="space-y-3">
            {genderOptions.map((option) => (
              <MriButton
                key={option.value}
                variant={formData.gender === option.value ? 'default' : 'secondary'}
                className="h-12 w-full rounded-2xl justify-start px-4"
                onClick={() => {
                  setFormData((prev) => ({ ...prev, gender: option.value }))
                  closeModal()
                }}
              >
                {option.label}
              </MriButton>
            ))}
          </div>
        </CenteredModal>
      )}

      {activeModal === 'nationality' && (
        <CenteredModal title={locales.character_creation?.nationality || 'Nacionalidade'} onClose={closeModal} className="w-[min(92vw,34rem)] max-w-[34rem]">
          <div className="space-y-4">
            <MriInput
              value={nationalitySearch}
              onChange={(event) => setNationalitySearch(event.target.value)}
              placeholder={locales.character_creation?.nationality_search || 'Buscar nacionalidade'}
            />

            <div className="max-h-[18rem] space-y-2 overflow-y-auto pr-1">
              {filteredNationalities.length > 0 ? (
                filteredNationalities.map((nationality) => (
                  <MriButton
                    key={nationality}
                    variant={formData.nationality === nationality ? 'default' : 'secondary'}
                    className="h-11 w-full justify-start rounded-2xl px-4"
                    onClick={() => {
                      setFormData((prev) => ({ ...prev, nationality }))
                      closeModal()
                    }}
                  >
                    {nationality}
                  </MriButton>
                ))
              ) : (
                <div className="rounded-2xl border border-border/70 bg-background/45 px-4 py-6 text-center text-sm text-muted-foreground">
                  {locales.character_creation?.nationality_empty || 'Nenhuma nacionalidade encontrada'}
                </div>
              )}
            </div>
          </div>
        </CenteredModal>
      )}

      {activeModal === 'birthdate' && (
        <CenteredModal title={locales.character_creation?.birthdate || 'Data de Nascimento'} onClose={closeModal} className="w-[min(92vw,24rem)] max-w-[24rem]">
          <div className="space-y-4">
            <div className="flex items-center justify-between gap-2">
              <MriButton
                type="button"
                variant="ghost"
                size="icon"
                className="h-10 w-10 rounded-2xl"
                onClick={handlePrevMonth}
                disabled={currentMonth === 1 && currentYear === minYear}
              >
                <ChevronLeft className="h-4 w-4" />
              </MriButton>

              <div className="grid flex-1 grid-cols-2 gap-2">
                <select
                  className="h-10 rounded-2xl border border-border/70 bg-background/50 px-3 text-sm text-foreground outline-none transition focus:border-primary/50"
                  value={currentMonth}
                  onChange={(event) => setCurrentMonth(Number.parseInt(event.target.value, 10))}
                >
                  {months.map((month, index) => (
                    <option key={month} value={index + 1}>
                      {month}
                    </option>
                  ))}
                </select>

                <select
                  className="h-10 rounded-2xl border border-border/70 bg-background/50 px-3 text-sm text-foreground outline-none transition focus:border-primary/50"
                  value={currentYear}
                  onChange={(event) => setCurrentYear(Number.parseInt(event.target.value, 10))}
                >
                  {Array.from({ length: maxYear - minYear + 1 }, (_, index) => minYear + index).reverse().map((year) => (
                    <option key={year} value={year}>
                      {year}
                    </option>
                  ))}
                </select>
              </div>

              <MriButton
                type="button"
                variant="ghost"
                size="icon"
                className="h-10 w-10 rounded-2xl"
                onClick={handleNextMonth}
                disabled={currentMonth === 12 && currentYear === maxYear}
              >
                <ChevronRight className="h-4 w-4" />
              </MriButton>
            </div>

            <div className="grid grid-cols-7 gap-1">
              {weekDays.map((day) => (
                <div
                  key={day}
                  className="flex h-8 items-center justify-center text-[11px] font-semibold uppercase tracking-[0.16em] text-muted-foreground"
                >
                  {day}
                </div>
              ))}
            </div>

            <div className="grid grid-cols-7 gap-1">
              {Array.from({ length: getFirstDayOfMonth(currentMonth, currentYear) }, (_, index) => (
                <div key={`empty-${index}`} className="aspect-square" />
              ))}

              {Array.from({ length: getDaysInMonth(currentMonth, currentYear) }, (_, index) => {
                const day = index + 1
                const isDisabled = isDateDisabled(day, currentMonth, currentYear)
                const isSelected = !!selectedDate
                  && selectedDate.getDate() === day
                  && selectedDate.getMonth() + 1 === currentMonth
                  && selectedDate.getFullYear() === currentYear

                return (
                  <button
                    key={day}
                    type="button"
                    disabled={isDisabled}
                    onClick={() => handleDateClick(day)}
                    className={[
                      'aspect-square rounded-2xl border text-sm font-medium transition-all',
                      isSelected
                        ? 'border-primary bg-primary text-primary-foreground'
                        : 'border-border/60 bg-background/45 text-foreground hover:border-primary/40 hover:bg-primary/10',
                      isDisabled ? 'cursor-not-allowed opacity-35 hover:bg-background/45 hover:border-border/60' : '',
                    ].join(' ')}
                  >
                    {day}
                  </button>
                )
              })}
            </div>
          </div>
        </CenteredModal>
      )}

      {errorMessage && (
        <CenteredModal title={locales.character_creation?.warning_title || 'Aviso'} onClose={() => setErrorMessage(null)} className="w-[min(92vw,28rem)] max-w-[28rem]">
          <div className="space-y-4">
            <p className="text-sm leading-6 text-muted-foreground">{errorMessage}</p>
            <MriButton className="h-11 w-full rounded-2xl" onClick={() => setErrorMessage(null)}>
              OK
            </MriButton>
          </div>
        </CenteredModal>
      )}
    </>
  )
}

import { type ReactNode, useEffect, useMemo, useRef, useState } from 'react'
import {
  MriButton,
  MriCard,
  MriCardContent,
  MriCardHeader,
  MriInput,
  MriModal,
  MriSectionHeader,
} from '@mriqbox/ui-kit'
import { ArrowLeft, Calendar, Check, ChevronDown, ChevronLeft, ChevronRight, Globe, ShieldPlus, User, X } from 'lucide-react'
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

type PickerModal = 'birthdate' | null

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

interface ThemedSelectProps<T extends string | number> {
  value: T
  options: Array<{ label: string; value: T }>
  onChange: (value: T) => void
  icon?: ReactNode
  className?: string
  size?: 'sm' | 'md'
}

function ThemedSelect<T extends string | number>({
  value,
  options,
  onChange,
  icon,
  className,
  size = 'md',
}: ThemedSelectProps<T>) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    if (!open) return
    const handleClickOutside = (event: MouseEvent) => {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [open])

  const selectedLabel = options.find((option) => option.value === value)?.label ?? ''
  const triggerHeight = size === 'sm' ? 'h-10' : 'h-12'
  const panelMaxHeight = options.length > 8 ? 'max-h-64' : ''

  return (
    <div className={cn('relative', className)} ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((current) => !current)}
        className={cn(
          'flex w-full items-center justify-between rounded-2xl border bg-background/45 px-4 text-left text-sm font-medium text-foreground outline-none transition hover:bg-background/60',
          triggerHeight,
          open ? 'border-primary/50' : 'border-border/70 hover:border-primary/40',
        )}
      >
        <span className="flex items-center gap-2 truncate">
          {icon && <span className="text-muted-foreground">{icon}</span>}
          {selectedLabel}
        </span>
        <ChevronDown
          className={cn(
            'h-4 w-4 shrink-0 text-muted-foreground transition-transform',
            open && 'rotate-180',
          )}
        />
      </button>
      {open && (
        <div className="absolute left-0 right-0 top-[calc(100%+0.5rem)] z-50 overflow-hidden rounded-2xl border border-border/70 bg-card shadow-2xl shadow-black/40">
          <div className={cn('overflow-y-auto', panelMaxHeight)}>
            {options.map((option) => {
              const isSelected = option.value === value
              return (
                <button
                  key={String(option.value)}
                  type="button"
                  onClick={() => {
                    onChange(option.value)
                    setOpen(false)
                  }}
                  className={cn(
                    'flex w-full items-center justify-between px-4 py-2.5 text-left text-sm transition',
                    isSelected
                      ? 'bg-primary/15 text-primary'
                      : 'text-foreground hover:bg-background/60',
                  )}
                >
                  <span>{option.label}</span>
                  {isSelected && <Check className="h-4 w-4" />}
                </button>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}

interface SearchableSelectProps {
  value: string
  options: string[]
  onChange: (value: string) => void
  placeholder?: string
  searchPlaceholder?: string
  emptyLabel?: string
  icon?: ReactNode
}

function SearchableSelect({
  value,
  options,
  onChange,
  placeholder,
  searchPlaceholder,
  emptyLabel,
  icon,
}: SearchableSelectProps) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const ref = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    if (!open) return
    const handleClickOutside = (event: MouseEvent) => {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setOpen(false)
        setQuery('')
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [open])

  const filtered = useMemo(() => {
    const trimmed = query.trim().toLowerCase()
    if (!trimmed) return options
    return options.filter((option) => option.toLowerCase().includes(trimmed))
  }, [options, query])

  const hasValue = value.trim().length > 0

  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((current) => !current)}
        className={cn(
          'flex h-12 w-full items-center justify-between rounded-2xl border bg-background/45 px-4 text-left text-sm font-medium outline-none transition hover:bg-background/60',
          open ? 'border-primary/50' : 'border-border/70 hover:border-primary/40',
        )}
      >
        <span className={cn('flex items-center gap-2 truncate', hasValue ? 'text-foreground' : 'text-muted-foreground')}>
          {icon && <span className="text-muted-foreground">{icon}</span>}
          {hasValue ? value : placeholder ?? ''}
        </span>
        <ChevronDown
          className={cn(
            'h-4 w-4 shrink-0 text-muted-foreground transition-transform',
            open && 'rotate-180',
          )}
        />
      </button>
      {open && (
        <div className="absolute left-0 right-0 top-[calc(100%+0.5rem)] z-50 overflow-hidden rounded-2xl border border-border/70 bg-card shadow-2xl shadow-black/40">
          <div className="border-b border-border/70 p-2">
            <MriInput
              autoFocus
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={searchPlaceholder ?? ''}
            />
          </div>
          <div className="max-h-64 overflow-y-auto py-1">
            {filtered.length > 0 ? (
              filtered.map((option) => {
                const isSelected = option === value
                return (
                  <button
                    key={option}
                    type="button"
                    onClick={() => {
                      onChange(option)
                      setOpen(false)
                      setQuery('')
                    }}
                    className={cn(
                      'flex w-full items-center justify-between px-4 py-2.5 text-left text-sm transition',
                      isSelected
                        ? 'bg-primary/15 text-primary'
                        : 'text-foreground hover:bg-background/60',
                    )}
                  >
                    <span>{option}</span>
                    {isSelected && <Check className="h-4 w-4" />}
                  </button>
                )
              })
            ) : (
              <div className="px-4 py-6 text-center text-sm text-muted-foreground">
                {emptyLabel ?? ''}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
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
    nationality: locales.character_creation?.default_nationality || 'Brasileiro',
    gender: '0',
    birthdate: '',
  })
  const [loading, setLoading] = useState(false)
  const [activeModal, setActiveModal] = useState<PickerModal>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const minYear = 1900
  const maxYear = 2006
  const minDate = new Date(minYear, 0, 1)
  const maxDate = new Date(maxYear, 11, 31)

  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth() + 1)
  const [currentYear, setCurrentYear] = useState(maxYear)
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)

  const fallbackMonths: string[] = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ]
  const fallbackWeekDays: string[] = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

  const months: string[] = Array.isArray(locales.character_creation?.months) && locales.character_creation.months.length === 12
    ? locales.character_creation.months
    : fallbackMonths
  const weekDays: string[] = Array.isArray(locales.character_creation?.week_days) && locales.character_creation.week_days.length === 7
    ? locales.character_creation.week_days
    : fallbackWeekDays

  const genderOptions = useMemo(
    () => [
      { label: locales.character_creation?.male || 'Masculino', value: '0' },
      { label: locales.character_creation?.female || 'Feminino', value: '1' },
    ],
    [locales.character_creation?.female, locales.character_creation?.male],
  )

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
                  <SearchableSelect
                    value={formData.nationality}
                    options={nationalities}
                    onChange={(value) => setFormData((prev) => ({ ...prev, nationality: value }))}
                    placeholder={locales.character_creation?.nationality_placeholder || 'Nacionalidade'}
                    searchPlaceholder={locales.character_creation?.nationality_search || 'Buscar nacionalidade'}
                    emptyLabel={locales.character_creation?.nationality_empty || 'Nenhuma nacionalidade encontrada'}
                    icon={<Globe className="h-4 w-4" />}
                  />
                </div>

                <div className="space-y-2">
                  <label className="text-sm font-medium text-foreground">
                    {locales.character_creation?.gender || 'Gênero'}
                  </label>
                  <ThemedSelect
                    value={formData.gender}
                    options={genderOptions}
                    onChange={(value) => setFormData((prev) => ({ ...prev, gender: value }))}
                    icon={<User className="h-4 w-4" />}
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

      {activeModal === 'birthdate' && (
        <CenteredModal title={locales.character_creation?.birthdate || 'Data de Nascimento'} onClose={closeModal} className="w-[min(92vw,24rem)] max-w-[24rem] overflow-visible">
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
                <ThemedSelect
                  size="sm"
                  value={currentMonth}
                  options={months.map((month, index) => ({ label: month, value: index + 1 }))}
                  onChange={(value) => setCurrentMonth(value)}
                />

                <ThemedSelect
                  size="sm"
                  value={currentYear}
                  options={Array.from({ length: maxYear - minYear + 1 }, (_, index) => minYear + index)
                    .reverse()
                    .map((year) => ({ label: String(year), value: year }))}
                  onChange={(value) => setCurrentYear(value)}
                />
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

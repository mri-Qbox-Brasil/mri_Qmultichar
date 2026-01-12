import { useState, useEffect, useRef } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { Input } from './ui/input'
import { ArrowLeft, Calendar, ChevronLeft, ChevronRight } from 'lucide-react'
import { nationalities } from '../data/nationalities'

declare function GetParentResourceName(): string

interface Theme {
  name: string;
  colors: {
    background: string;
    card: string;
    border: string;
    text: {
      primary: string;
      secondary: string;
      muted: string;
    };
    accent: {
      primary: string;
      secondary: string;
      success: string;
      danger: string;
    };
  };
}

interface CharacterCreationProps {
  slot: number
  theme: Theme | null
  onCancel: () => void
  onSuccess: () => void
  locales?: any
}

export function CharacterCreation({ slot, theme, onCancel, onSuccess, locales = {} }: CharacterCreationProps) {
  const [formData, setFormData] = useState({
    firstname: '',
    lastname: '',
    nationality: 'Brasileiro',
    gender: '0',
    birthdate: '',
  })
  const [loading, setLoading] = useState(false)
  const [showCalendar, setShowCalendar] = useState(false)
  const [showNationalitySelect, setShowNationalitySelect] = useState(false)
  const [showGenderSelect, setShowGenderSelect] = useState(false)
  const calendarRef = useRef<HTMLDivElement>(null)

  // Calendário visual
  const minYear = 1900
  const maxYear = 2006
  const minDate = new Date(minYear, 0, 1)
  const maxDate = new Date(maxYear, 11, 31)

  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth() + 1)
  const [currentYear, setCurrentYear] = useState(maxYear)
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)

  const months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ]

  const weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

  const getDaysInMonth = (month: number, year: number) => {
    return new Date(year, month, 0).getDate()
  }

  const getFirstDayOfMonth = (month: number, year: number) => {
    return new Date(year, month - 1, 1).getDay()
  }

  const isDateDisabled = (day: number, month: number, year: number) => {
    const date = new Date(year, month - 1, day)
    return date < minDate || date > maxDate
  }

  const handleDateClick = (day: number) => {
    if (isDateDisabled(day, currentMonth, currentYear)) return
    
    const date = new Date(currentYear, currentMonth - 1, day)
    setSelectedDate(date)
    const formattedDate = `${String(day).padStart(2, '0')}/${String(currentMonth).padStart(2, '0')}/${currentYear}`
    setFormData({ ...formData, birthdate: formattedDate })
    setShowCalendar(false)
  }

  const handlePrevMonth = () => {
    if (currentMonth === 1) {
      if (currentYear > minYear) {
        setCurrentMonth(12)
        setCurrentYear(currentYear - 1)
      }
    } else {
      setCurrentMonth(currentMonth - 1)
    }
  }

  const handleNextMonth = () => {
    if (currentMonth === 12) {
      if (currentYear < maxYear) {
        setCurrentMonth(1)
        setCurrentYear(currentYear + 1)
      }
    } else {
      setCurrentMonth(currentMonth + 1)
    }
  }

  // Fechar calendário e selects ao clicar fora
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (calendarRef.current && !calendarRef.current.contains(event.target as Node)) {
        setShowCalendar(false)
      }
      // Fechar selects ao clicar fora
      const target = event.target as HTMLElement
      if (!target.closest('.relative')) {
        setShowNationalitySelect(false)
        setShowGenderSelect(false)
      }
    }

    if (showCalendar || showNationalitySelect || showGenderSelect) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [showCalendar, showNationalitySelect, showGenderSelect])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.birthdate) {
      alert('Por favor, selecione uma data de nascimento')
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
          gender: parseInt(formData.gender),
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
          alert('Erro ao criar personagem: ' + (data.message || 'Erro desconhecido'))
        }
      })
      .catch((err) => {
        console.error('Erro ao criar personagem:', err)
        alert('Erro ao criar personagem')
      })
      .finally(() => {
        setLoading(false)
      })
  }

  return (
    <div className="max-w-2xl mx-auto w-full px-4">
      <Card 
        style={{
          backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
          borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)'
        }}
      >
        <CardHeader>
          <div className="flex items-center justify-between">
            <Button
              variant="ghost"
              size="icon"
              onClick={onCancel}
              style={{
                color: theme?.colors.text.primary || '#F8FAFC'
              }}
            >
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <CardTitle style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
              Criar Personagem - Slot {slot}
            </CardTitle>
            <div className="w-10" />
          </div>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label 
                className="block text-sm font-medium mb-2"
                style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}
              >
                Primeiro Nome
              </label>
              <Input
                type="text"
                required
                value={formData.firstname}
                onChange={(e) =>
                  setFormData({ ...formData, firstname: e.target.value })
                }
                style={{
                  backgroundColor: 'rgba(255, 255, 255, 0.05)',
                  borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  color: theme?.colors.text.primary || '#F8FAFC'
                }}
                placeholder="João"
              />
            </div>

            <div>
              <label 
                className="block text-sm font-medium mb-2"
                style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}
              >
                Último Nome
              </label>
              <Input
                type="text"
                required
                value={formData.lastname}
                onChange={(e) =>
                  setFormData({ ...formData, lastname: e.target.value })
                }
                style={{
                  backgroundColor: 'rgba(255, 255, 255, 0.05)',
                  borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  color: theme?.colors.text.primary || '#F8FAFC'
                }}
                placeholder="Silva"
              />
            </div>

            <div className="relative">
              <label 
                className="block text-sm font-medium mb-2"
                style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}
              >
                Nacionalidade
              </label>
              <div className="relative">
                <Input
                  type="text"
                  required
                  readOnly
                  value={formData.nationality}
                  onClick={() => setShowNationalitySelect(!showNationalitySelect)}
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                    color: theme?.colors.text.primary || '#F8FAFC',
                    cursor: 'pointer'
                  }}
                  placeholder="Selecione uma nacionalidade"
                />
                {showNationalitySelect && (
                  <div 
                    className="absolute z-50 w-full mt-1 max-h-60 overflow-y-auto rounded-md border shadow-lg"
                    style={{
                      backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                      borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)'
                    }}
                  >
                    {nationalities.map((nationality) => (
                      <div
                        key={nationality}
                        onClick={() => {
                          setFormData({ ...formData, nationality })
                          setShowNationalitySelect(false)
                        }}
                        className="px-4 py-2 cursor-pointer hover:bg-white/10"
                        style={{
                          color: theme?.colors.text.primary || '#F8FAFC',
                          backgroundColor: formData.nationality === nationality ? theme?.colors.accent.primary + '33' : 'transparent'
                        }}
                      >
                        {nationality}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            <div className="relative">
              <label 
                className="block text-sm font-medium mb-2"
                style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}
              >
                Gênero
              </label>
              <div className="relative">
                <Input
                  type="text"
                  required
                  readOnly
                  value={formData.gender === '0' ? 'Masculino' : 'Feminino'}
                  onClick={() => setShowGenderSelect(!showGenderSelect)}
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                    color: theme?.colors.text.primary || '#F8FAFC',
                    cursor: 'pointer'
                  }}
                  placeholder="Selecione o gênero"
                />
                {showGenderSelect && (
                  <div 
                    className="absolute z-50 w-full mt-1 rounded-md border shadow-lg"
                    style={{
                      backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                      borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)'
                    }}
                  >
                    <div
                      onClick={() => {
                        setFormData({ ...formData, gender: '0' })
                        setShowGenderSelect(false)
                      }}
                      className="px-4 py-2 cursor-pointer hover:bg-white/10"
                      style={{
                        color: theme?.colors.text.primary || '#F8FAFC',
                        backgroundColor: formData.gender === '0' ? theme?.colors.accent.primary + '33' : 'transparent'
                      }}
                    >
                      Masculino
                    </div>
                    <div
                      onClick={() => {
                        setFormData({ ...formData, gender: '1' })
                        setShowGenderSelect(false)
                      }}
                      className="px-4 py-2 cursor-pointer hover:bg-white/10"
                      style={{
                        color: theme?.colors.text.primary || '#F8FAFC',
                        backgroundColor: formData.gender === '1' ? theme?.colors.accent.primary + '33' : 'transparent'
                      }}
                    >
                      {locales.character_creation?.female || 'Feminino'}
                    </div>
                  </div>
                )}
              </div>
            </div>

            <div className="relative">
              <label 
                className="block text-sm font-medium mb-2"
                style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}
              >
                Data de Nascimento
              </label>
              <div className="relative">
                <Input
                  type="text"
                  required
                  readOnly
                  value={formData.birthdate}
                  onClick={() => setShowCalendar(!showCalendar)}
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                    color: theme?.colors.text.primary || '#F8FAFC',
                    cursor: 'pointer'
                  }}
                  placeholder="DD/MM/YYYY"
                />
                <Calendar className="absolute right-3 top-1/2 transform -translate-y-1/2 w-4 h-4" style={{ color: theme?.colors.text.muted || '#94A3B8' }} />
                {showCalendar && (
                  <div 
                    ref={calendarRef}
                    className="absolute z-50 mt-1 p-2 rounded-md border shadow-lg"
                    style={{
                      backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                      borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                      width: '240px',
                      top: '100%',
                      marginTop: '4px'
                    }}
                  >
                    {/* Header do calendário */}
                    <div className="flex items-center justify-between mb-2">
                      <button
                        type="button"
                        onClick={handlePrevMonth}
                        disabled={currentMonth === 1 && currentYear === minYear}
                        style={{
                          color: theme?.colors.text.primary || '#F8FAFC',
                          opacity: (currentMonth === 1 && currentYear === minYear) ? 0.3 : 1,
                          cursor: (currentMonth === 1 && currentYear === minYear) ? 'not-allowed' : 'pointer',
                          backgroundColor: 'transparent',
                          border: 'none',
                          padding: '4px'
                        }}
                        className="hover:bg-white/10 rounded"
                      >
                        <ChevronLeft className="w-4 h-4" />
                      </button>
                      <div className="flex items-center gap-1">
                        <select
                          value={currentMonth}
                          onChange={(e) => setCurrentMonth(parseInt(e.target.value))}
                          style={{
                            backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                            borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                            color: theme?.colors.text.primary || '#F8FAFC',
                            padding: '2px 6px',
                            borderRadius: '4px',
                            border: '1px solid',
                            fontSize: '12px',
                            cursor: 'pointer'
                          }}
                        >
                          {months.map((month, index) => (
                            <option 
                              key={index + 1} 
                              value={index + 1}
                              style={{
                                backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                                color: theme?.colors.text.primary || '#F8FAFC'
                              }}
                            >
                              {month}
                            </option>
                          ))}
                        </select>
                        <select
                          value={currentYear}
                          onChange={(e) => setCurrentYear(parseInt(e.target.value))}
                          style={{
                            backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                            borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                            color: theme?.colors.text.primary || '#F8FAFC',
                            padding: '2px 6px',
                            borderRadius: '4px',
                            border: '1px solid',
                            fontSize: '12px',
                            cursor: 'pointer'
                          }}
                        >
                          {Array.from({ length: maxYear - minYear + 1 }, (_, i) => minYear + i).reverse().map(year => (
                            <option 
                              key={year} 
                              value={year}
                              style={{
                                backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                                color: theme?.colors.text.primary || '#F8FAFC'
                              }}
                            >
                              {year}
                            </option>
                          ))}
                        </select>
                      </div>
                      <button
                        type="button"
                        onClick={handleNextMonth}
                        disabled={currentMonth === 12 && currentYear === maxYear}
                        style={{
                          color: theme?.colors.text.primary || '#F8FAFC',
                          opacity: (currentMonth === 12 && currentYear === maxYear) ? 0.3 : 1,
                          cursor: (currentMonth === 12 && currentYear === maxYear) ? 'not-allowed' : 'pointer',
                          backgroundColor: 'transparent',
                          border: 'none',
                          padding: '4px'
                        }}
                        className="hover:bg-white/10 rounded"
                      >
                        <ChevronRight className="w-4 h-4" />
                      </button>
                    </div>

                    {/* Dias da semana */}
                    <div className="grid grid-cols-7 gap-0.5 mb-1">
                      {weekDays.map(day => (
                        <div
                          key={day}
                          className="text-center text-xs font-medium py-1"
                          style={{ color: theme?.colors.text.muted || '#94A3B8' }}
                        >
                          {day}
                        </div>
                      ))}
                    </div>

                    {/* Grade de dias */}
                    <div className="grid grid-cols-7 gap-0.5">
                      {Array.from({ length: getFirstDayOfMonth(currentMonth, currentYear) }, (_, i) => (
                        <div key={`empty-${i}`} style={{ aspectRatio: '1' }} />
                      ))}
                      {Array.from({ length: getDaysInMonth(currentMonth, currentYear) }, (_, i) => {
                        const day = i + 1
                        const isDisabled = isDateDisabled(day, currentMonth, currentYear)
                        const isSelected = selectedDate && 
                          selectedDate.getDate() === day &&
                          selectedDate.getMonth() + 1 === currentMonth &&
                          selectedDate.getFullYear() === currentYear
                        
                        const textColor = isSelected 
                          ? '#FFFFFF'
                          : isDisabled
                          ? (theme?.colors.text.muted || '#94A3B8')
                          : (theme?.colors.text.primary || '#F8FAFC')
                        
                        const bgColor = isSelected 
                          ? (theme?.colors.accent.primary || '#3B82F6')
                          : isDisabled
                          ? 'rgba(255, 255, 255, 0.02)'
                          : 'rgba(255, 255, 255, 0.05)'
                        
                        return (
                          <button
                            key={day}
                            type="button"
                            onClick={() => handleDateClick(day)}
                            disabled={isDisabled}
                            style={{
                              aspectRatio: '1',
                              borderRadius: '4px',
                              border: `1px solid ${isSelected ? (theme?.colors.accent.primary || '#3B82F6') : (theme?.colors.border || 'rgba(51, 65, 85, 0.5)')}`,
                              backgroundColor: bgColor,
                              color: textColor,
                              cursor: isDisabled ? 'not-allowed' : 'pointer',
                              transition: 'all 0.2s',
                              opacity: isDisabled ? 0.4 : 1,
                              fontSize: '12px',
                              fontWeight: isSelected ? '600' : '400',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center'
                            }}
                            onMouseEnter={(e) => {
                              if (!isDisabled && !isSelected) {
                                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.15)'
                              }
                            }}
                            onMouseLeave={(e) => {
                              if (!isDisabled && !isSelected) {
                                e.currentTarget.style.backgroundColor = bgColor
                              }
                            }}
                          >
                            {day}
                          </button>
                        )
                      })}
                    </div>
                  </div>
                )}
              </div>
            </div>

            <div className="flex gap-4 pt-4">
              <Button
                type="button"
                variant="outline"
                onClick={onCancel}
                disabled={loading}
                style={{
                  borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  color: theme?.colors.text.primary || '#F8FAFC',
                  backgroundColor: 'transparent'
                }}
                className="flex-1"
              >
                Cancelar
              </Button>
              <Button
                type="submit"
                disabled={loading}
                style={{
                  backgroundColor: theme?.colors.accent.success || '#22C55E',
                  color: '#FFFFFF'
                }}
                className="flex-1"
              >
                {loading ? 'Criando...' : 'Criar Personagem'}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}

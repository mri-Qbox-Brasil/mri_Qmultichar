import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { Input } from './ui/input'
import { ArrowLeft, Calendar } from 'lucide-react'
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
}

export function CharacterCreation({ slot, theme, onCancel, onSuccess }: CharacterCreationProps) {
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

  // Calendário simples
  const minYear = 1900
  const maxYear = 2006
  const years = Array.from({ length: maxYear - minYear + 1 }, (_, i) => minYear + i).reverse()
  const months = [
    { value: 1, label: 'Janeiro' },
    { value: 2, label: 'Fevereiro' },
    { value: 3, label: 'Março' },
    { value: 4, label: 'Abril' },
    { value: 5, label: 'Maio' },
    { value: 6, label: 'Junho' },
    { value: 7, label: 'Julho' },
    { value: 8, label: 'Agosto' },
    { value: 9, label: 'Setembro' },
    { value: 10, label: 'Outubro' },
    { value: 11, label: 'Novembro' },
    { value: 12, label: 'Dezembro' },
  ]

  const [selectedDay, setSelectedDay] = useState<number | null>(null)
  const [selectedMonth, setSelectedMonth] = useState<number | null>(null)
  const [selectedYear, setSelectedYear] = useState<number | null>(null)

  const getDaysInMonth = (month: number, year: number) => {
    return new Date(year, month, 0).getDate()
  }

  const handleDateSelect = (day: number, month: number, year: number) => {
    setSelectedDay(day)
    setSelectedMonth(month)
    setSelectedYear(year)
    const formattedDate = `${String(day).padStart(2, '0')}/${String(month).padStart(2, '0')}/${year}`
    setFormData({ ...formData, birthdate: formattedDate })
    setShowCalendar(false)
  }

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

            <div>
              <label 
                className="block text-sm font-medium mb-2"
                style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}
              >
                Gênero
              </label>
              <select
                required
                value={formData.gender}
                onChange={(e) =>
                  setFormData({ ...formData, gender: e.target.value })
                }
                className="flex h-10 w-full rounded-md border px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2"
                style={{
                  backgroundColor: 'rgba(255, 255, 255, 0.05)',
                  borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                  color: theme?.colors.text.primary || '#F8FAFC'
                }}
              >
                <option value="0">Masculino</option>
                <option value="1">Feminino</option>
              </select>
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
                    className="absolute z-50 w-full mt-1 p-4 rounded-md border shadow-lg"
                    style={{
                      backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
                      borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)'
                    }}
                  >
                    <div className="grid grid-cols-3 gap-2 mb-4">
                      <select
                        value={selectedDay || ''}
                        onChange={(e) => setSelectedDay(parseInt(e.target.value))}
                        style={{
                          backgroundColor: 'rgba(255, 255, 255, 0.05)',
                          borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                          color: theme?.colors.text.primary || '#F8FAFC'
                        }}
                        className="rounded-md border px-2 py-1"
                      >
                        <option value="">Dia</option>
                        {selectedMonth && selectedYear && Array.from({ length: getDaysInMonth(selectedMonth, selectedYear) }, (_, i) => i + 1).map(day => (
                          <option key={day} value={day}>{day}</option>
                        ))}
                      </select>
                      <select
                        value={selectedMonth || ''}
                        onChange={(e) => {
                          setSelectedMonth(parseInt(e.target.value))
                          setSelectedDay(null)
                        }}
                        style={{
                          backgroundColor: 'rgba(255, 255, 255, 0.05)',
                          borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                          color: theme?.colors.text.primary || '#F8FAFC'
                        }}
                        className="rounded-md border px-2 py-1"
                      >
                        <option value="">Mês</option>
                        {months.map(month => (
                          <option key={month.value} value={month.value}>{month.label}</option>
                        ))}
                      </select>
                      <select
                        value={selectedYear || ''}
                        onChange={(e) => {
                          setSelectedYear(parseInt(e.target.value))
                          setSelectedDay(null)
                        }}
                        style={{
                          backgroundColor: 'rgba(255, 255, 255, 0.05)',
                          borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                          color: theme?.colors.text.primary || '#F8FAFC'
                        }}
                        className="rounded-md border px-2 py-1"
                      >
                        <option value="">Ano</option>
                        {years.map(year => (
                          <option key={year} value={year}>{year}</option>
                        ))}
                      </select>
                    </div>
                    {selectedDay && selectedMonth && selectedYear && (
                      <Button
                        type="button"
                        onClick={() => handleDateSelect(selectedDay, selectedMonth, selectedYear)}
                        style={{
                          backgroundColor: theme?.colors.accent.primary || '#3B82F6',
                          color: '#FFFFFF'
                        }}
                        className="w-full"
                      >
                        Confirmar Data
                      </Button>
                    )}
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

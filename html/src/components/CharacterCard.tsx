import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { ArrowLeft, Play, Trash2 } from 'lucide-react'

interface Character {
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
    label: string
    grade: number | { name: string }
  }
  gang: {
    label: string
    grade: { name: string }
  }
}

interface CharacterCardProps {
  character: Character
  onBack: () => void
  onPlay: () => void
  onDelete: () => void
}

export function CharacterCard({ character, onBack, onPlay, onDelete }: CharacterCardProps) {
  const formatMoney = (amount: number) => {
    return amount.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
  }

  const jobGrade = typeof character.job.grade === 'object' 
    ? character.job.grade.name 
    : character.job.grade

  return (
    <div className="max-w-2xl mx-auto">
      <Card className="bg-slate-800/50 border-slate-700">
        <CardHeader>
          <div className="flex items-center justify-between">
            <Button
              variant="ghost"
              size="icon"
              onClick={onBack}
              className="text-white hover:bg-slate-700"
            >
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <CardTitle className="text-white text-2xl">
              {character.charinfo.firstname} {character.charinfo.lastname}
            </CardTitle>
            <div className="w-10" />
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">CitizenID</p>
              <p className="text-white font-mono text-sm">{character.citizenid}</p>
            </div>
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">Gênero</p>
              <p className="text-white">
                {character.charinfo.gender === 0 ? 'Masculino' : 'Feminino'}
              </p>
            </div>
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">Data de Nascimento</p>
              <p className="text-white">{character.charinfo.birthdate}</p>
            </div>
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">Nacionalidade</p>
              <p className="text-white">{character.charinfo.nationality}</p>
            </div>
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">Número da Conta</p>
              <p className="text-white">{character.charinfo.account}</p>
            </div>
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">Telefone</p>
              <p className="text-white">{character.charinfo.phone}</p>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="bg-green-900/30 border border-green-700/50 p-4 rounded-lg">
              <p className="text-green-400 text-sm">Banco</p>
              <p className="text-green-300 text-xl font-bold">
                {formatMoney(character.money.bank)}
              </p>
            </div>
            <div className="bg-yellow-900/30 border border-yellow-700/50 p-4 rounded-lg">
              <p className="text-yellow-400 text-sm">Carteira</p>
              <p className="text-yellow-300 text-xl font-bold">
                {formatMoney(character.money.cash)}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">Emprego</p>
              <p className="text-white font-semibold">{character.job.label}</p>
              <p className="text-slate-300 text-xs">Nível: {jobGrade}</p>
            </div>
            <div className="bg-slate-700/50 p-4 rounded-lg">
              <p className="text-slate-400 text-sm">Gangue</p>
              <p className="text-white font-semibold">{character.gang.label}</p>
              <p className="text-slate-300 text-xs">Patente: {character.gang.grade.name}</p>
            </div>
          </div>

          <div className="flex gap-4 pt-4">
            <Button
              className="flex-1 bg-blue-600 hover:bg-blue-700 h-12 text-lg"
              onClick={onPlay}
            >
              <Play className="h-5 w-5 mr-2" />
              Jogar
            </Button>
            <Button
              variant="destructive"
              className="flex-1 h-12 text-lg"
              onClick={onDelete}
            >
              <Trash2 className="h-5 w-5 mr-2" />
              Deletar
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}


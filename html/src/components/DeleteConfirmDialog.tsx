import { MriActionModal, MriBadge } from '@mriqbox/ui-kit'
import { AlertTriangle } from 'lucide-react'

interface DeleteConfirmDialogProps {
  open: boolean
  onClose: () => void
  onConfirm: () => void
  characterName?: string
  locales?: any
}

export function DeleteConfirmDialog({
  open,
  onClose,
  onConfirm,
  characterName,
  locales = {},
}: DeleteConfirmDialogProps) {
  if (!open) {
    return null
  }

  return (
    <MriActionModal
      title={locales.characters?.confirm_delete_title || 'Confirmar Exclusão'}
      icon={AlertTriangle}
      variant="destructive"
      confirmLabel={locales.buttons?.delete || locales.characters?.delete_character || 'Deletar'}
      cancelLabel={locales.buttons?.cancel || 'Cancelar'}
      onClose={onClose}
      onConfirm={onConfirm}
      maxWidth="30rem"
    >
      <div className="space-y-4">
        <p className="text-sm leading-6 text-muted-foreground">
          {locales.characters?.confirm_delete || 'Tem certeza que deseja deletar este personagem?'}
        </p>

        {characterName && (
          <MriBadge variant="outline" className="rounded-full px-4 py-2 text-sm font-medium">
            {characterName}
          </MriBadge>
        )}

        <p className="text-sm leading-6 text-destructive">
          {locales.characters?.delete_warning || 'Esta ação não pode ser desfeita!'}
        </p>
      </div>
    </MriActionModal>
  )
}

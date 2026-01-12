import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from './ui/dialog'
import { Button } from './ui/button'
import { AlertTriangle } from 'lucide-react'

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

interface DeleteConfirmDialogProps {
  open: boolean
  onClose: () => void
  onConfirm: () => void
  characterName?: string
  theme: Theme | null
  locales?: any
}

export function DeleteConfirmDialog({ open, onClose, onConfirm, characterName, theme, locales = {} }: DeleteConfirmDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent 
        style={{ 
          backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
          borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)'
        }}
      >
        <DialogHeader>
          <div className="flex items-center gap-3">
            <AlertTriangle 
              className="w-6 h-6" 
              style={{ color: theme?.colors.accent.danger || '#EF4444' }} 
            />
            <DialogTitle style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
              Confirmar Exclusão
            </DialogTitle>
          </div>
          <DialogDescription style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}>
            {locales.characters?.confirm_delete || 'Tem certeza que deseja deletar este personagem?'} {' '}
            <span style={{ color: theme?.colors.text.primary || '#F8FAFC', fontWeight: 'bold' }}>
              {characterName || ''}
            </span>
            {' '}
            {locales.characters?.delete_warning || 'Esta ação não pode ser desfeita!'}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={onClose}
            style={{
              borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
              color: theme?.colors.text.primary || '#F8FAFC',
              backgroundColor: 'transparent'
            }}
          >
            {locales.buttons?.cancel || 'Cancelar'}
          </Button>
          <Button
            type="button"
            onClick={onConfirm}
            style={{
              backgroundColor: theme?.colors.accent.danger || '#EF4444',
              color: '#FFFFFF'
            }}
          >
            {locales.buttons?.delete || 'Deletar'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}


Config.Themes = {
    -- Tema Dark (shadcn padrão)
    dark = {
        name = 'Dark',
        colors = {
            background = 'rgba(2, 6, 23, 0.95)', -- slate-950
            card = 'rgba(15, 23, 42, 0.9)', -- slate-900
            border = 'rgba(51, 65, 85, 0.5)', -- slate-700
            text = {
                primary = '#F8FAFC', -- slate-50
                secondary = '#CBD5E1', -- slate-300
                muted = '#94A3B8', -- slate-400
            },
            accent = {
                primary = '#3B82F6', -- blue-500
                secondary = '#6366F1', -- indigo-500
                success = '#22C55E', -- green-500
                danger = '#EF4444', -- red-500
            },
            button = {
                primary = '#3B82F6',
                primaryHover = '#2563EB',
                danger = '#EF4444',
                dangerHover = '#DC2626',
            }
        }
    },

    -- Tema Blue (sutil)
    blue = {
        name = 'Blue',
        colors = {
            background = 'rgba(8, 47, 73, 0.95)', -- blue-950
            card = 'rgba(30, 58, 138, 0.9)', -- blue-900
            border = 'rgba(59, 130, 246, 0.3)', -- blue-500
            text = {
                primary = '#EFF6FF', -- blue-50
                secondary = '#DBEAFE', -- blue-100
                muted = '#BFDBFE', -- blue-200
            },
            accent = {
                primary = '#3B82F6', -- blue-500
                secondary = '#60A5FA', -- blue-400
                success = '#22C55E', -- green-500
                danger = '#EF4444', -- red-500
            },
            button = {
                primary = '#3B82F6',
                primaryHover = '#2563EB',
                danger = '#EF4444',
                dangerHover = '#DC2626',
            }
        }
    },

    -- Tema Purple (sutil)
    purple = {
        name = 'Purple',
        colors = {
            background = 'rgba(30, 27, 75, 0.95)', -- indigo-950
            card = 'rgba(55, 48, 163, 0.9)', -- indigo-900
            border = 'rgba(99, 102, 241, 0.3)', -- indigo-500
            text = {
                primary = '#EEF2FF', -- indigo-50
                secondary = '#E0E7FF', -- indigo-100
                muted = '#C7D2FE', -- indigo-200
            },
            accent = {
                primary = '#8B5CF6', -- purple-500
                secondary = '#A78BFA', -- purple-400
                success = '#22C55E', -- green-500
                danger = '#EF4444', -- red-500
            },
            button = {
                primary = '#8B5CF6',
                primaryHover = '#7C3AED',
                danger = '#EF4444',
                dangerHover = '#DC2626',
            }
        }
    },

    -- Tema Green (sutil)
    green = {
        name = 'Green',
        colors = {
            background = 'rgba(5, 46, 22, 0.95)', -- green-950
            card = 'rgba(20, 83, 45, 0.9)', -- green-900
            border = 'rgba(34, 197, 94, 0.3)', -- green-500
            text = {
                primary = '#F0FDF4', -- green-50
                secondary = '#DCFCE7', -- green-100
                muted = '#BBF7D0', -- green-200
            },
            accent = {
                primary = '#22C55E', -- green-500
                secondary = '#4ADE80', -- green-400
                success = '#22C55E', -- green-500
                danger = '#EF4444', -- red-500
            },
            button = {
                primary = '#22C55E',
                primaryHover = '#16A34A',
                danger = '#EF4444',
                dangerHover = '#DC2626',
            }
        }
    },

    -- Tema Red (sutil)
    red = {
        name = 'Red',
        colors = {
            background = 'rgba(69, 10, 10, 0.95)', -- red-950
            card = 'rgba(127, 29, 29, 0.9)', -- red-900
            border = 'rgba(239, 68, 68, 0.3)', -- red-500
            text = {
                primary = '#FEF2F2', -- red-50
                secondary = '#FEE2E2', -- red-100
                muted = '#FECACA', -- red-200
            },
            accent = {
                primary = '#EF4444', -- red-500
                secondary = '#F87171', -- red-400
                success = '#22C55E', -- green-500
                danger = '#EF4444', -- red-500
            },
            button = {
                primary = '#EF4444',
                primaryHover = '#DC2626',
                danger = '#EF4444',
                dangerHover = '#DC2626',
            }
        }
    },

    -- Tema Orange (sutil)
    orange = {
        name = 'Orange',
        colors = {
            background = 'rgba(67, 20, 7, 0.95)', -- orange-950
            card = 'rgba(124, 45, 18, 0.9)', -- orange-900
            border = 'rgba(249, 115, 22, 0.3)', -- orange-500
            text = {
                primary = '#FFF7ED', -- orange-50
                secondary = '#FFEDD5', -- orange-100
                muted = '#FED7AA', -- orange-200
            },
            accent = {
                primary = '#F97316', -- orange-500
                secondary = '#FB923C', -- orange-400
                success = '#22C55E', -- green-500
                danger = '#EF4444', -- red-500
            },
            button = {
                primary = '#F97316',
                primaryHover = '#EA580C',
                danger = '#EF4444',
                dangerHover = '#DC2626',
            }
        }
    },

    -- Tema MRI (Refinado conforme a imagem)
    mri = {
        name = 'MRI',
        colors = {
            background = 'rgba(9, 9, 11, 0.98)', -- Quase preto (Zinc-950)
            card = 'rgba(18, 18, 22, 0.95)', -- Dark Zinc/Slate
            border = 'rgba(39, 39, 42, 0.5)', -- Zinc-800
            text = {
                primary = '#FFFFFF', -- Branco puro
                secondary = '#A1A1AA', -- Zinc-400
                muted = '#71717A', -- Zinc-500
            },
            accent = {
                primary = '#00FFA3', -- Neon Green (Vibrante)
                secondary = '#00D186', -- Neon Green Darker
                success = '#00FFA3',
                danger = '#FF3B3B', -- Vermelho vibrante
            },
            button = {
                primary = '#00FFA3', -- Fundo neon
                primaryHover = '#00D186',
                danger = '#FF3B3B',
                dangerHover = '#E63535',
            }
        }
    },
    
    -- Tema Dashboard Dark (baseado nas imagens do dashboard)
    dashboard = {
        name = 'Dashboard Dark',
        colors = {
            background = 'rgba(0, 0, 0, 1)', -- Preto puro
            card = 'rgba(0, 0, 0, 0.95)', -- Preto quase puro (cards)
            border = 'rgba(51, 65, 85, 0.4)', -- Slate-600 (bordas sutis)
            text = {
                primary = '#F8FAFC', -- Slate-50 (texto principal branco)
                secondary = '#CBD5E1', -- Slate-300 (texto secundário cinza claro)
                muted = '#94A3B8', -- Slate-400 (texto muted cinza médio)
            },
            accent = {
                primary = '#22C55E', -- Green-500 (verde - dinheiro em mãos)
                secondary = '#3B82F6', -- Blue-500 (azul - dinheiro no banco)
                success = '#22C55E', -- Green-500 (sucesso)
                danger = '#EF4444', -- Red-500 (perigo/vermelho)
            },
            button = {
                primary = '#22C55E', -- Green-500 (botão primário verde)
                primaryHover = '#16A34A', -- Green-600 (hover verde escuro)
                danger = '#EF4444', -- Red-500 (botão de perigo)
                dangerHover = '#DC2626', -- Red-600 (hover vermelho escuro)
            },
        },
    },
}

return Config.Themes

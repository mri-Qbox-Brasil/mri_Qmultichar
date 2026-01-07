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

    -- Tema MRI (Inspirado na logo - baseado na imagem)
    mri = {
        name = 'MRI',
        colors = {
            background = 'rgba(5, 46, 22, 0.95)', -- green-950 (fundo escuro da imagem)
            card = 'rgba(20, 83, 45, 0.9)', -- green-900 (painéis verdes escuros)
            border = 'rgba(34, 197, 94, 0.3)', -- green-500 (brilho verde claro)
            text = {
                primary = '#F0FDF4', -- green-50 (texto principal claro - FOFDF4)
                secondary = '#DCFCE7', -- green-100 (texto secundário - DCFCE7)
                muted = '#BBF7D0', -- green-200 (texto muted - BBF7D0)
            },
            accent = {
                primary = '#22C55E', -- green-500 (destaque verde - 22CBE/22C55E)
                secondary = '#16A34A', -- green-600 (hover/destaque - 16A344)
                success = '#22C55E', -- green-500
                danger = '#EF4444', -- red-500 (vermelho da imagem)
            },
            button = {
                primary = '#22C55E', -- green-500 (22CBE)
                primaryHover = '#16A34A', -- green-600 (16A344)
                danger = '#EF4444', -- red-500
                dangerHover = '#DC2626', -- red-600
            }
        }
    },
}

return Config.Themes

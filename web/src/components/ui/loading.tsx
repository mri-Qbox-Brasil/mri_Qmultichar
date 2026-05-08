import { cn } from "@/lib/utils"

interface LoadingProps {
  size?: 'sm' | 'md' | 'lg'
  variant?: 'spinner' | 'dots' | 'pulse' | 'bars'
  className?: string
}

export function Loading({ size = 'md', variant = 'spinner', className }: LoadingProps) {
  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-8 h-8',
    lg: 'w-12 h-12'
  }

  if (variant === 'spinner') {
    return (
      <div className={cn("animate-spin rounded-full border-2 border-current border-t-transparent", sizeClasses[size], className)} />
    )
  }

  if (variant === 'dots') {
    return (
      <div className={cn("flex gap-1", className)}>
        <div className={cn("rounded-full bg-current animate-bounce", sizeClasses[size])} style={{ animationDelay: '0ms' }} />
        <div className={cn("rounded-full bg-current animate-bounce", sizeClasses[size])} style={{ animationDelay: '150ms' }} />
        <div className={cn("rounded-full bg-current animate-bounce", sizeClasses[size])} style={{ animationDelay: '300ms' }} />
      </div>
    )
  }

  if (variant === 'pulse') {
    return (
      <div className={cn("rounded-full bg-current animate-pulse", sizeClasses[size], className)} />
    )
  }

  if (variant === 'bars') {
    return (
      <div className={cn("flex gap-1 items-end", className)}>
        <div className="w-1 bg-current animate-pulse" style={{ height: '40%', animationDelay: '0ms' }} />
        <div className="w-1 bg-current animate-pulse" style={{ height: '60%', animationDelay: '150ms' }} />
        <div className="w-1 bg-current animate-pulse" style={{ height: '80%', animationDelay: '300ms' }} />
        <div className="w-1 bg-current animate-pulse" style={{ height: '100%', animationDelay: '450ms' }} />
        <div className="w-1 bg-current animate-pulse" style={{ height: '80%', animationDelay: '600ms' }} />
        <div className="w-1 bg-current animate-pulse" style={{ height: '60%', animationDelay: '750ms' }} />
        <div className="w-1 bg-current animate-pulse" style={{ height: '40%', animationDelay: '900ms' }} />
      </div>
    )
  }

  return null
}


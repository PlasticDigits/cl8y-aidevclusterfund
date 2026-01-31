export function Hero() {
  return (
    <section className="relative py-16 px-4 text-center overflow-hidden">
      {/* Premium background with hero image */}
      <div 
        className="absolute inset-0 bg-cover bg-center bg-no-repeat"
        style={{ backgroundImage: 'url(/images/hero-background.png)' }}
      />
      {/* Gradient overlay for better text readability */}
      <div className="absolute inset-0 bg-gradient-to-b from-[var(--black)]/60 via-transparent to-[var(--black)]/80" />
      
      <div className="relative z-10 max-w-4xl mx-auto">
        {/* CL8Y Logo */}
        <div className="flex justify-center mb-4">
          <img 
            src="/images/CLAY-512.png" 
            alt="CL8Y Logo" 
            className="w-24 h-24 md:w-32 md:h-32 drop-shadow-lg"
          />
        </div>
        
        <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold font-display mb-4">
          <span className="text-[var(--gold)]">CL8Y</span>{' '}
          <span className="text-[var(--text-primary)]">Fund</span>
        </h1>
        
        <p className="text-xl md:text-2xl text-[var(--text-secondary)] mb-6 max-w-2xl mx-auto">
          Funding AI inference costs for{' '}
          <span className="text-[var(--aqua)]">AGPL open source</span>{' '}
          blockchain development
        </p>
        
        <div className="flex flex-wrap justify-center gap-4 text-sm text-[var(--text-muted)]">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 bg-[var(--aqua)] rounded-full animate-pulse" />
            <span>Public Research</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 bg-[var(--gold)] rounded-full animate-pulse" />
            <span>Community Driven</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 bg-[var(--ember)] rounded-full animate-pulse" />
            <span>1:1 Matching</span>
          </div>
        </div>
      </div>
    </section>
  );
}

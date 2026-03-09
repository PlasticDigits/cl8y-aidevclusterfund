import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { FUNDING_MILESTONES, TOTAL_FUNDING_TARGET, TOTAL_AUDIT_DONATIONS } from '@/lib/config';

interface Props {
  totalDeposited: number;
}

export function FundingTimeline({ totalDeposited }: Props) {
  const totalRaised = totalDeposited;
  const percentage = (totalRaised / TOTAL_FUNDING_TARGET) * 100;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Funding Timeline</CardTitle>
        <p className="text-sm text-[var(--text-muted)] mt-1">
          Proposed dApps funded by community contributions
        </p>
      </CardHeader>

      <CardContent>
        {/* Overall progress */}
        <div className="mb-8">
          <div className="flex justify-between text-sm mb-2">
            <span className="text-[var(--text-secondary)]">Raised</span>
            <span className="font-mono text-[var(--gold)]">
              ${totalRaised.toLocaleString()} / ${TOTAL_FUNDING_TARGET.toLocaleString()}
            </span>
          </div>
          <p className="text-xs text-[var(--text-muted)] mb-2">
            Includes community donations + CZodiac 1:1 matching.
            Audit/Review services (${TOTAL_AUDIT_DONATIONS.toLocaleString()}) donated by Ceramic.
          </p>
          <div className="h-4 bg-[var(--charcoal)] rounded-full overflow-hidden relative">
            <div
              className="h-full bg-gradient-to-r from-[var(--gold-dark)] to-[var(--gold)] transition-all duration-500"
              style={{ width: `${Math.min(percentage, 100)}%` }}
            />
            {/* Milestone markers */}
            {FUNDING_MILESTONES.map((milestone) => {
              const pos = (milestone.cumulativeTotal / TOTAL_FUNDING_TARGET) * 100;
              return (
                <div
                  key={milestone.id}
                  className="absolute top-0 bottom-0 w-0.5 bg-[var(--midnight)]"
                  style={{ left: `${pos}%` }}
                />
              );
            })}
          </div>
        </div>

        {/* Milestones list */}
        <div className="space-y-3">
          {FUNDING_MILESTONES.map((milestone, i) => {
            const isReached = totalRaised >= milestone.cumulativeTotal;
            const prevTotal = i > 0 ? FUNDING_MILESTONES[i - 1].cumulativeTotal : 0;
            const isInProgress = !isReached && totalRaised >= prevTotal;

            return (
              <div
                key={milestone.id}
                className={`p-4 rounded-lg border transition-colors ${
                  isReached
                    ? 'bg-[var(--gold)]/10 border-[var(--gold)]'
                    : isInProgress
                    ? 'bg-[var(--aqua)]/10 border-[var(--aqua)]'
                    : 'bg-[var(--charcoal)] border-transparent'
                }`}
              >
                <div className="flex justify-between items-start">
                  <div className="flex items-start gap-3">
                    <div
                      className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                        isReached
                          ? 'bg-[var(--gold)] text-[var(--black)]'
                          : isInProgress
                          ? 'bg-[var(--aqua)] text-[var(--black)]'
                          : 'bg-[var(--midnight)] text-[var(--text-muted)]'
                      }`}
                    >
                      {isReached ? '✓' : milestone.id}
                    </div>
                    <div>
                      <h4
                        className={`font-medium ${
                          isReached || isInProgress
                            ? 'text-[var(--text-primary)]'
                            : 'text-[var(--text-muted)]'
                        }`}
                      >
                        {milestone.name}
                      </h4>
                      <p className="mt-1 text-xs text-[var(--text-muted)]">
                        {milestone.leadTimeWeeks} weeks &middot; AI ${milestone.aiCost.toLocaleString()} + QA ${milestone.qaCost.toLocaleString()}
                        <span className="text-[var(--aqua)]"> + ${milestone.auditCost.toLocaleString()} audit donated</span>
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-mono text-sm text-[var(--text-secondary)]">
                      ${(milestone.aiCost + milestone.qaCost + milestone.auditCost).toLocaleString()}
                    </p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Disclaimer */}
        <div className="mt-6 p-4 bg-[var(--midnight)] rounded-lg border border-[var(--charcoal)]">
          <p className="text-xs text-[var(--text-muted)] leading-relaxed">
            <strong className="text-[var(--ember)]">Note:</strong> These are suggestions only.
            Some dApps may be dropped or replaced based on community feedback and technical feasibility.
            All raised funds will be solely used for developing new blockchain technology that is AGPL open source.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

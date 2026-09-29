import { APP_CONFIG, EXERCISE_KEYS } from '@fit-odyssey/config';

export default function HomePage() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center p-6 text-center">
      <div className="max-w-2xl bg-odyssey-card border border-odyssey-border p-8 rounded-2xl shadow-2xl backdrop-blur-sm">
        <div className="inline-block px-3 py-1 bg-amber-500/10 text-amber-400 border border-amber-500/20 rounded-full text-xs font-semibold tracking-wider uppercase mb-4">
          Odisha Heritage Edition
        </div>
        <h1 className="text-4xl sm:text-5xl font-extrabold tracking-tight bg-gradient-to-r from-amber-400 via-orange-400 to-red-500 bg-clip-text text-transparent">
          {APP_CONFIG.NAME}
        </h1>
        <p className="mt-4 text-lg text-slate-300">
          {APP_CONFIG.TAGLINE}
        </p>

        <div className="mt-8 grid grid-cols-3 gap-4 text-left">
          <div className="p-4 bg-slate-900/60 rounded-xl border border-slate-800">
            <span className="text-xs text-slate-400 uppercase tracking-wide">Exercise</span>
            <p className="text-base font-semibold text-white mt-1">{EXERCISE_KEYS.SQUAT}</p>
          </div>
          <div className="p-4 bg-slate-900/60 rounded-xl border border-slate-800">
            <span className="text-xs text-slate-400 uppercase tracking-wide">Exercise</span>
            <p className="text-base font-semibold text-white mt-1">{EXERCISE_KEYS.PUSHUP}</p>
          </div>
          <div className="p-4 bg-slate-900/60 rounded-xl border border-slate-800">
            <span className="text-xs text-slate-400 uppercase tracking-wide">Exercise</span>
            <p className="text-base font-semibold text-white mt-1">{EXERCISE_KEYS.PLANK}</p>
          </div>
        </div>

        <div className="mt-8 pt-6 border-t border-slate-800 flex items-center justify-between text-xs text-slate-500">
          <span>Status: Foundation Ready (Phase 1)</span>
          <span>Web Command Center</span>
        </div>
      </div>
    </main>
  );
}

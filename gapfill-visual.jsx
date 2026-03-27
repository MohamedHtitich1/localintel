import { useState } from "react";
import {
  ComposedChart,
  Line,
  Area,
  Scatter,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";

// Simulated Kenya Nyanza U5 mortality data (based on actual DHS surveys)
const observed = [
  { year: 1993, value: 199 },
  { year: 1998, value: 172 },
  { year: 2003, value: 150 },
  { year: 2008, value: 128 },
  { year: 2014, value: 82 },
  { year: 2022, value: 46 },
];

// FMM spline interpolation (pre-computed on log scale, back-transformed)
const interpolated = [
  { year: 1993, est: 199, ci_lo: 195, ci_hi: 203 },
  { year: 1994, est: 192, ci_lo: 118, ci_hi: 314 },
  { year: 1995, est: 186, ci_lo: 114, ci_hi: 304 },
  { year: 1996, est: 181, ci_lo: 111, ci_hi: 296 },
  { year: 1997, est: 176, ci_lo: 108, ci_hi: 288 },
  { year: 1998, est: 172, ci_lo: 169, ci_hi: 175 },
  { year: 1999, est: 166, ci_lo: 102, ci_hi: 272 },
  { year: 2000, est: 161, ci_lo: 98, ci_hi: 263 },
  { year: 2001, est: 157, ci_lo: 96, ci_hi: 257 },
  { year: 2002, est: 153, ci_lo: 94, ci_hi: 250 },
  { year: 2003, est: 150, ci_lo: 147, ci_hi: 153 },
  { year: 2004, est: 146, ci_lo: 89, ci_hi: 238 },
  { year: 2005, est: 141, ci_lo: 86, ci_hi: 231 },
  { year: 2006, est: 137, ci_lo: 84, ci_hi: 224 },
  { year: 2007, est: 132, ci_lo: 81, ci_hi: 216 },
  { year: 2008, est: 128, ci_lo: 126, ci_hi: 130 },
  { year: 2009, est: 120, ci_lo: 73, ci_hi: 196 },
  { year: 2010, est: 112, ci_lo: 69, ci_hi: 183 },
  { year: 2011, est: 104, ci_lo: 64, ci_hi: 170 },
  { year: 2012, est: 96, ci_lo: 59, ci_hi: 157 },
  { year: 2013, est: 89, ci_lo: 54, ci_hi: 145 },
  { year: 2014, est: 82, ci_lo: 80, ci_hi: 84 },
  { year: 2015, est: 76, ci_lo: 47, ci_hi: 124 },
  { year: 2016, est: 70, ci_lo: 43, ci_hi: 115 },
  { year: 2017, est: 65, ci_lo: 40, ci_hi: 106 },
  { year: 2018, est: 59, ci_lo: 36, ci_hi: 97 },
  { year: 2019, est: 55, ci_lo: 34, ci_hi: 90 },
  { year: 2020, est: 51, ci_lo: 31, ci_hi: 83 },
  { year: 2021, est: 48, ci_lo: 30, ci_hi: 79 },
  { year: 2022, est: 46, ci_lo: 45, ci_hi: 47 },
];

// Log-transformed view
const logTransformed = interpolated.map((d) => ({
  ...d,
  est_log: Math.log(d.est).toFixed(2),
  ci_lo_log: Math.log(d.ci_lo).toFixed(2),
  ci_hi_log: Math.log(d.ci_hi).toFixed(2),
}));

const observedLog = observed.map((d) => ({
  year: d.year,
  value_log: Math.log(d.value).toFixed(2),
}));

const steps = [
  {
    id: 1,
    title: "Raw DHS Survey Data",
    desc: "Irregularly spaced observations from DHS survey waves (every 3\u201313 years)",
    color: "#ef4444",
  },
  {
    id: 2,
    title: "Transform",
    desc: "Apply log (mortality) or logit (proportions) to move data to unconstrained scale",
    color: "#f59e0b",
  },
  {
    id: 3,
    title: "FMM Cubic Spline",
    desc: "Fit Forsythe-Malcolm-Moler spline on transformed scale \u2014 exact interpolation, no edge overshoot",
    color: "#3b82f6",
  },
  {
    id: 4,
    title: "GAM Uncertainty",
    desc: "Penalized GAM estimates standard errors reflecting data density + sigma_floor for calibration",
    color: "#8b5cf6",
  },
  {
    id: 5,
    title: "Back-Transform",
    desc: "Apply exp() or inverse-logit to get estimates and CIs on original scale, respecting natural bounds",
    color: "#10b981",
  },
];

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length > 0) {
    const d = interpolated.find((x) => x.year === label);
    const obs = observed.find((x) => x.year === label);
    return (
      <div className="bg-white border border-gray-300 rounded p-3 text-sm shadow-lg">
        <p className="font-bold text-gray-800">{label}</p>
        {obs && (
          <p className="text-red-600">
            Observed: {obs.value} per 1,000
          </p>
        )}
        {d && (
          <>
            <p className="text-blue-600">
              Estimate: {d.est} per 1,000
            </p>
            <p className="text-gray-500">
              95% CI: [{d.ci_lo}, {d.ci_hi}]
            </p>
          </>
        )}
      </div>
    );
  }
  return null;
};

const CustomScatter = (props) => {
  const { cx, cy } = props;
  return (
    <circle
      cx={cx}
      cy={cy}
      r={7}
      fill="#ef4444"
      stroke="#fff"
      strokeWidth={2}
    />
  );
};

export default function GapFillVisual() {
  const [activeStep, setActiveStep] = useState(null);
  const [view, setView] = useState("result");

  const chartData = interpolated.map((d) => {
    const obs = observed.find((o) => o.year === d.year);
    return {
      year: d.year,
      estimate: d.est,
      ci_range: [d.ci_lo, d.ci_hi],
      observed: obs ? obs.value : undefined,
    };
  });

  const logChartData = logTransformed.map((d) => {
    const obs = observedLog.find((o) => o.year === d.year);
    return {
      year: d.year,
      estimate: parseFloat(d.est_log),
      ci_range: [parseFloat(d.ci_lo_log), parseFloat(d.ci_hi_log)],
      observed: obs ? parseFloat(obs.value_log) : undefined,
    };
  });

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-5xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            DHS Gap-Filling Method
          </h1>
          <p className="text-gray-600 text-lg">
            FMM Spline + GAM Uncertainty \u2014 Calibrated Temporal Interpolation
          </p>
          <p className="text-gray-500 mt-1">
            Example: Under-5 Mortality, Kenya \u2014 Nyanza Province
          </p>
        </div>

        {/* Pipeline Steps */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">
            Processing Pipeline
          </h2>
          <div className="flex items-start gap-2">
            {steps.map((step, i) => (
              <div key={step.id} className="flex items-start flex-1">
                <div
                  className="cursor-pointer transition-all duration-200"
                  onMouseEnter={() => setActiveStep(step.id)}
                  onMouseLeave={() => setActiveStep(null)}
                  style={{
                    opacity: activeStep && activeStep !== step.id ? 0.4 : 1,
                    transform:
                      activeStep === step.id ? "scale(1.02)" : "scale(1)",
                  }}
                >
                  <div
                    className="rounded-lg p-3 mb-2"
                    style={{ backgroundColor: step.color + "15" }}
                  >
                    <div
                      className="w-8 h-8 rounded-full flex items-center justify-center text-white font-bold text-sm mb-2"
                      style={{ backgroundColor: step.color }}
                    >
                      {step.id}
                    </div>
                    <p
                      className="font-semibold text-sm"
                      style={{ color: step.color }}
                    >
                      {step.title}
                    </p>
                    <p className="text-xs text-gray-500 mt-1 leading-relaxed">
                      {step.desc}
                    </p>
                  </div>
                </div>
                {i < steps.length - 1 && (
                  <div className="flex items-center pt-6 px-1">
                    <svg
                      width="20"
                      height="20"
                      viewBox="0 0 20 20"
                      fill="none"
                    >
                      <path
                        d="M7 4l6 6-6 6"
                        stroke="#9ca3af"
                        strokeWidth="2"
                        strokeLinecap="round"
                      />
                    </svg>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* View Toggle */}
        <div className="flex gap-3 mb-4">
          {[
            { id: "result", label: "Final Result (Original Scale)" },
            { id: "transformed", label: "Transformed Scale (log)" },
            { id: "comparison", label: "Why FMM?" },
          ].map((v) => (
            <button
              key={v.id}
              onClick={() => setView(v.id)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                view === v.id
                  ? "bg-blue-600 text-white"
                  : "bg-white text-gray-600 border border-gray-300 hover:bg-gray-50"
              }`}
            >
              {v.label}
            </button>
          ))}
        </div>

        {/* Main Chart */}
        {view !== "comparison" && (
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
            <h2 className="text-lg font-semibold text-gray-800 mb-1">
              {view === "result"
                ? "Under-5 Mortality Rate \u2014 Nyanza, Kenya"
                : "Log-Transformed Scale"}
            </h2>
            <p className="text-sm text-gray-500 mb-4">
              {view === "result"
                ? "Deaths per 1,000 live births. Red dots = DHS survey observations. Blue line = FMM spline interpolation. Shaded band = calibrated 95% prediction interval."
                : "The spline operates on this scale. Log transform ensures predictions stay positive and encodes proportional (not absolute) changes."}
            </p>
            <ResponsiveContainer width="100%" height={420}>
              <ComposedChart
                data={view === "result" ? chartData : logChartData}
                margin={{ top: 10, right: 30, left: 10, bottom: 10 }}
              >
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis
                  dataKey="year"
                  tick={{ fontSize: 12 }}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fontSize: 12 }}
                  tickLine={false}
                  label={{
                    value:
                      view === "result"
                        ? "Deaths per 1,000"
                        : "log(mortality)",
                    angle: -90,
                    position: "insideLeft",
                    style: { fontSize: 12, fill: "#6b7280" },
                  }}
                />
                <Tooltip content={<CustomTooltip />} />
                <Area
                  dataKey="ci_range"
                  fill="#3b82f6"
                  fillOpacity={0.12}
                  stroke="none"
                  name="95% CI"
                  isAnimationActive={false}
                />
                <Line
                  dataKey="estimate"
                  stroke="#3b82f6"
                  strokeWidth={2.5}
                  dot={false}
                  name="FMM Spline"
                  isAnimationActive={false}
                />
                <Scatter
                  dataKey="observed"
                  name="DHS Survey"
                  shape={<CustomScatter />}
                  isAnimationActive={false}
                />
                {observed.map((o) => (
                  <ReferenceLine
                    key={o.year}
                    x={o.year}
                    stroke="#ef444440"
                    strokeDasharray="2 4"
                  />
                ))}
              </ComposedChart>
            </ResponsiveContainer>

            {/* Legend */}
            <div className="flex gap-6 mt-4 text-xs text-gray-500 justify-center">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-red-500" />
                <span>DHS survey observations (exact)</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-6 h-0.5 bg-blue-500" />
                <span>FMM spline interpolation</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-6 h-3 bg-blue-500 opacity-20 rounded" />
                <span>95% prediction interval (\u03C3 floor = 0.25)</span>
              </div>
            </div>
          </div>
        )}

        {/* Comparison View: Why FMM? */}
        {view === "comparison" && (
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
            <h2 className="text-lg font-semibold text-gray-800 mb-4">
              Method Comparison: Why FMM Spline?
            </h2>
            <div className="grid grid-cols-3 gap-6">
              {/* V1: GAM */}
              <div className="border border-red-200 rounded-lg p-4 bg-red-50">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 rounded-full bg-red-500 text-white flex items-center justify-center text-xs font-bold">
                    \u2717
                  </div>
                  <h3 className="font-semibold text-red-800">V1: Pure GAM</h3>
                </div>
                <div className="space-y-3 text-sm">
                  <p className="text-gray-700">
                    Penalized regression spline smooths <em>through</em> data
                    points instead of passing through them exactly.
                  </p>
                  <div className="bg-white rounded p-3 border border-red-100">
                    <p className="font-mono text-xs text-red-700">
                      Nyanza 1998:
                    </p>
                    <p className="font-mono text-xs">
                      Observed: <strong>199</strong>
                    </p>
                    <p className="font-mono text-xs">
                      GAM estimate: <strong>206</strong>
                    </p>
                    <p className="font-mono text-xs text-red-600">
                      \u2260 Not exact interpolation
                    </p>
                  </div>
                  <p className="text-gray-500 text-xs">
                    Treats survey estimates as noisy \u2014 but DHS values ARE the
                    ground truth for that survey period.
                  </p>
                </div>
              </div>

              {/* V2: Natural Spline */}
              <div className="border border-amber-200 rounded-lg p-4 bg-amber-50">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 rounded-full bg-amber-500 text-white flex items-center justify-center text-xs font-bold">
                    \u2717
                  </div>
                  <h3 className="font-semibold text-amber-800">
                    V2: Natural Cubic Spline
                  </h3>
                </div>
                <div className="space-y-3 text-sm">
                  <p className="text-gray-700">
                    Exact interpolation, but global coupling causes catastrophic
                    edge overshoot.
                  </p>
                  <div className="bg-white rounded p-3 border border-amber-100">
                    <p className="font-mono text-xs text-amber-700">
                      Nairobi LOO 2022:
                    </p>
                    <p className="font-mono text-xs">
                      Observed: <strong>44</strong>
                    </p>
                    <p className="font-mono text-xs">
                      Natural spline: <strong>119</strong>
                    </p>
                    <p className="font-mono text-xs text-red-600">
                      170% error at edge!
                    </p>
                  </div>
                  <p className="text-gray-500 text-xs">
                    A change at one end of the series propagates and distorts
                    the entire curve.
                  </p>
                </div>
              </div>

              {/* V3: FMM */}
              <div className="border border-green-200 rounded-lg p-4 bg-green-50">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 rounded-full bg-green-500 text-white flex items-center justify-center text-xs font-bold">
                    \u2713
                  </div>
                  <h3 className="font-semibold text-green-800">
                    V3: FMM Spline (selected)
                  </h3>
                </div>
                <div className="space-y-3 text-sm">
                  <p className="text-gray-700">
                    Forsythe-Malcolm-Moler: local tangent computation. Exact
                    interpolation with no edge overshoot.
                  </p>
                  <div className="bg-white rounded p-3 border border-green-100">
                    <p className="font-mono text-xs text-green-700">
                      Properties:
                    </p>
                    <p className="font-mono text-xs">
                      \u2713 Passes through every point
                    </p>
                    <p className="font-mono text-xs">
                      \u2713 Local \u2014 no edge propagation
                    </p>
                    <p className="font-mono text-xs">
                      \u2713 Smooth C\u00B2 continuity
                    </p>
                  </div>
                  <p className="text-gray-500 text-xs">
                    Point estimates from FMM, uncertainty from GAM \u2014 best of
                    both worlds.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Stats Panel */}
        <div className="grid grid-cols-4 gap-4 mb-8">
          {[
            {
              label: "Indicators",
              value: "60",
              sub: "of 62 with subnational data",
              color: "#3b82f6",
            },
            {
              label: "Countries",
              value: "35",
              sub: "of 44 SSA with DHS surveys",
              color: "#10b981",
            },
            {
              label: "Annual Estimates",
              value: "459K",
              sub: "from 106K observations (4.3\u00D7)",
              color: "#8b5cf6",
            },
            {
              label: "Fit Errors",
              value: "23",
              sub: "of 31,727 region-series (0.07%)",
              color: "#f59e0b",
            },
          ].map((s) => (
            <div
              key={s.label}
              className="bg-white rounded-xl shadow-sm border border-gray-200 p-4"
            >
              <p className="text-sm text-gray-500">{s.label}</p>
              <p className="text-3xl font-bold" style={{ color: s.color }}>
                {s.value}
              </p>
              <p className="text-xs text-gray-400 mt-1">{s.sub}</p>
            </div>
          ))}
        </div>

        {/* Transform Explanation */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">
            Transform Selection
          </h2>
          <p className="text-sm text-gray-600 mb-4">
            The transform and the cubic spline are two separate layers that work
            together. The transform moves data to an unconstrained scale{" "}
            <em>before</em> fitting, then predictions are back-transformed{" "}
            <em>after</em>.
          </p>
          <div className="grid grid-cols-2 gap-6">
            <div className="border border-blue-200 rounded-lg p-4 bg-blue-50">
              <h3 className="font-semibold text-blue-800 mb-2">
                log transform \u2014 7 indicators
              </h3>
              <p className="text-sm text-gray-600 mb-2">
                For strictly positive values where proportional changes matter.
              </p>
              <div className="font-mono text-xs space-y-1">
                <p>
                  <span className="text-blue-600">Forward:</span> y \u2192 log(y)
                </p>
                <p>
                  <span className="text-blue-600">Back:</span> \u0177 \u2192 exp(\u0177)
                </p>
                <p>
                  <span className="text-blue-600">Guarantee:</span> exp(x) &gt;{" "}
                  0 always
                </p>
              </div>
              <div className="mt-3 text-xs text-gray-500">
                U5 mortality, infant mortality, neonatal, perinatal, child
                mortality, median years education (W/M)
              </div>
            </div>
            <div className="border border-purple-200 rounded-lg p-4 bg-purple-50">
              <h3 className="font-semibold text-purple-800 mb-2">
                logit transform \u2014 55 indicators
              </h3>
              <p className="text-sm text-gray-600 mb-2">
                For proportions (0\u2013100%) with natural floor/ceiling effects.
              </p>
              <div className="font-mono text-xs space-y-1">
                <p>
                  <span className="text-purple-600">Forward:</span> p \u2192
                  log(p/(1-p))
                </p>
                <p>
                  <span className="text-purple-600">Back:</span> \u0177 \u2192
                  1/(1+exp(-\u0177))
                </p>
                <p>
                  <span className="text-purple-600">Guarantee:</span> result \u2208
                  [0, 100]
                </p>
              </div>
              <div className="mt-3 text-xs text-gray-500">
                Stunting, vaccination, ANC visits, literacy, HIV prevalence,
                wealth quintiles, WASH indicators...
              </div>
            </div>
          </div>
        </div>

        {/* CI Calibration */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">
            CI Calibration via Leave-One-Out Cross-Validation
          </h2>
          <p className="text-sm text-gray-600 mb-4">
            GAM standard errors alone only captured smoothing uncertainty \u2014
            42.9% coverage instead of 95%. Adding a minimum prediction SE
            (sigma_floor) calibrates the intervals empirically.
          </p>
          <div className="relative">
            {/* 95% target line */}
            <div className="absolute left-16 right-8" style={{ bottom: `${(95 / 100) * 160 + 28}px` }}>
              <div className="border-t-2 border-dashed border-red-400 relative">
                <span className="absolute right-0 -top-5 text-xs text-red-500 font-medium">95% target</span>
              </div>
            </div>
            <div className="flex items-end gap-4 px-16 pb-7" style={{ height: "220px" }}>
              {[
                { floor: "0.00", cov: 42.9, target: false },
                { floor: "0.10", cov: 71.4, target: false },
                { floor: "0.15", cov: 77.1, target: false },
                { floor: "0.20", cov: 82.9, target: false },
                { floor: "0.25", cov: 94.3, target: true },
                { floor: "0.30", cov: 97.1, target: false },
              ].map((d) => (
                <div key={d.floor} className="flex-1 flex flex-col items-center">
                  <span className={`text-xs font-mono mb-1 ${d.target ? "font-bold text-blue-700" : "text-gray-500"}`}>
                    {d.cov}%
                  </span>
                  <div
                    className="w-full rounded-t transition-all"
                    style={{
                      height: `${(d.cov / 100) * 160}px`,
                      backgroundColor: d.target ? "#3b82f6" : "#d1d5db",
                      border: d.target ? "2px solid #1d4ed8" : "none",
                    }}
                  />
                  <span
                    className={`text-xs mt-2 font-mono ${d.target ? "font-bold text-blue-700" : "text-gray-500"}`}
                  >
                    {d.floor}
                  </span>
                </div>
              ))}
            </div>
          </div>
          <p className="text-center text-xs text-gray-400 mt-2">
            sigma_floor value \u2192 Selected: <strong>0.25</strong> (94.3% coverage on Kenya, 86.7% multi-country)
          </p>
        </div>
      </div>
    </div>
  );
}

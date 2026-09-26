function figPaths = auto_export_figure(figHandle, category, figureType, slug, options)
%AUTO_EXPORT_FIGURE Export a figure to FIGURES/<category>/<figureType>/.
%
% DESCRIPTION:
%   Saves a figure as a vector PDF and, optionally, as a MATLAB .fig file.
%   Used by the genetic-algorithm workflow of Section 4.2 of the paper to
%   archive the Pareto front returned by each phase. No paper figure depends
%   on this function: every figure published in the paper is written with
%   EXPORTGRAPHICS by the GEN_PAPER_* scripts in CONFIGURATION/.
%
%   Implemented with built-in MATLAB graphics only, so it runs unchanged on
%   Windows, macOS and Linux and requires no external tool.
%
% SYNTAX:
%   figPaths = auto_export_figure(figHandle, category, figureType, slug)
%   figPaths = auto_export_figure(figHandle, category, figureType, slug, options)
%
% INPUTS:
%   figHandle  - Figure handle. Use GCF for the current figure, or [] to
%                auto-detect the current figure.
%   category   - Destination subdirectory of FIGURES/, e.g. 'GA_MULTIOBJECTIVE'.
%   figureType - Destination subdirectory of the category, e.g. 'PDS'.
%   slug       - Base name for the file. A char row vector, or a cell array of
%                char row vectors which are joined with '_vs_'.
%   options    - (optional) struct with fields:
%                .formats   - cell array drawn from {'pdf','fig'}.
%                             Default {'pdf','fig'}.
%                .timestamp - logical, append _yyyymmdd_HHMMSS. Default true.
%
% OUTPUT:
%   figPaths   - Cell array of the full paths written.
%
% NOTE ON PATHS:
%   The destination is resolved relative to this file, so the function works
%   from any current directory and contains no absolute path.

if nargin < 5 || isempty(options)
    options = struct();
end
if ~isfield(options, 'formats') || isempty(options.formats)
    options.formats = {'pdf', 'fig'};
end
if ~isfield(options, 'timestamp')
    options.timestamp = true;
end

if nargin < 1 || isempty(figHandle)
    figHandle = gcf;
end
if ~isgraphics(figHandle, 'figure')
    error('auto_export_figure:InvalidHandle', ...
          'figHandle must be a valid figure handle.');
end

% Join a cell-array slug into a single comparison name.
if iscell(slug)
    slug = strjoin(slug, '_vs_');
end

% FIGURES/ is the parent of the directory holding this file (FIGURES/UTILS/).
thisDir    = fileparts(mfilename('fullpath'));
figuresDir = fileparts(thisDir);
outDir     = fullfile(figuresDir, category, figureType);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

baseName = slug;
if options.timestamp
    baseName = sprintf('%s_%s', baseName, datestr(now, 'yyyymmdd_HHMMSS')); %#ok<TNOW1,DATST>
end

figPaths = {};
for k = 1:numel(options.formats)
    fmt      = lower(options.formats{k});
    fullPath = fullfile(outDir, [baseName '.' fmt]);
    switch fmt
        case 'pdf'
            exportgraphics(figHandle, fullPath, ...
                           'ContentType', 'vector', 'BackgroundColor', 'white');
        case 'fig'
            savefig(figHandle, fullPath);
        otherwise
            warning('auto_export_figure:UnsupportedFormat', ...
                    'Format ''%s'' is not supported and was skipped.', fmt);
            continue
    end
    figPaths{end+1} = fullPath; %#ok<AGROW>
    fprintf('  Figure written: %s\n', fullPath);
end

end

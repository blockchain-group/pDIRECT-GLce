function [ret_minval, final_xatmin, history] = parallel_dDirect_GL...
    (Problem, bounds, opts)
%--------------------------------------------------------------------------
% Function   : parallel_dDirect_GL
% Author 1   : Linas Stripinis          (linas.stripinis@mif.vu.lt)
% Author 2   : Remigijus Paualvicius    (remigijus.paulavicius@mif.vu.lt)
% Created on : 04/19/2020
% Purpose    : DIRECT optimization algorithm for box constraints.
%--------------------------------------------------------------------------
% [minima, xatmin, history] = parallel_dDirect_GL(Problem, bounds, opts)
%       parallel  - parallel version of the algorithm
%       d         - dynamic memory management in data structure
%       DIRECT    - DIRECT(DIvide a hyper-RECTangle) algorithm
%       G         - Enhancing the global search
%       L         - Enhancing the local search
%
% Input parameters:
%       Problem - Structure containing problem
%                 Problem.f       = Objective function handle
%
%       bounds  - (n x 2) matrix of bound constraints LB <= x <= UB
%                 The first column is the LB bounds and the second
%                 column contains the UB bounds
%
%       opts    - MATLAB structure which contains options.
%                 opts.maxevals  = max. number of function evals
%                 opts.maxits    = max. number of iterations
%                 opts.maxdeep   = max. number of rect. divisions
%                 opts.testflag  = 1 if globalmin known, 0 otherwise
%                 opts.globalmin = globalmin (if known)
%                 opts.showits   = 1 print iteration status
%                 opts.tol       = tolerance for termination if
%                                  testflag = 1
%
% Output parameters:
%       minima  -  best minimum value which was founded
%
%       xatmin  - coordinate of minimal value
%
%       history - (iterations x 4) matrix of iteration history
%                 First column coresponds iterations
%                 Second column coresponds number of objective function
%                 evaluations
%                 Third column coresponds minima value of objecgtive
%                 function which was founded at iterations
%                 Third column coresponds time cost of the algorithm
%
% Original DIRECT implementation taken from:
%--------------------------------------------------------------------------
% D.R. Jones, C.D. Perttunen, and B.E. Stuckman. "Lipschitzian
% Optimization Without the Lipschitz Constant". Journal of Optimization
% Theory and Application, 79(1):157-181, (1993). DOI 10.1007/BF00941892
%
% Selection of potential optimal hyper-rectangles taken from:
%--------------------------------------------------------------------------
% Stripinis, L., Paulavicius, R., Zilinskas, J.: Improved scheme for
% selection of potentially optimal hyperrectangles in DIRECT. Optimization
% Letters (2018). ISSN 1862-4472, 12 (7), 1699-1712,
% DOI: 10.1007/s11590-017-1228-4
%--------------------------------------------------------------------------

% Get options
if nargin < 3
    opts = [];
end
SS = Options(opts, nargout);

spmd                              % Execute code in parallel on labs
%--------------------------------------------------------------------------
    for i = 1:10000
        if labindex == 1 
            labSend([], 2:SS.workers)
        else
            labReceive(1);
        end         
    end
    % Alocate sets and create initial variables
    [MV, MD, MSS, CE, third, VAL, SS] = Alocate(bounds, SS);
    
    if labindex == 1 
        [MV, MD, MSS, CE, DT, VAL, SS, xmin, fmin] = Initialization(...
            Problem, MV, MD, MSS, CE, VAL, SS);
    else        
        DT = labReceive(1);
    end
    while VAL.perror > SS.TOL       % Main loop
        [MSS, CE, MV, MD, DT] = subdivision(VAL, Problem, DT, MSS, CE,...
            third, MV, MD);
        if labindex == 1            % Gather information from workers
            [DT, fmin, VAL, SS, xmin] = Master(VAL, SS, DT, MSS);
        else                        % Receive information from master
            [DT, ~, TAG] = labReceive(1); 
            if TAG == 1
                VAL.perror = -1; 
            end
        end
    end                             % End of while
%--------------------------------------------------------------------------
end                                 % End of SPMD block
ret_minval      = fmin{1};          % Return value
TT              = SS{1};
VAL             = VAL{1};
final_xatmin    = abs(VAL.b-VAL.a).*xmin{1} + VAL.a;  % Return point
history         = TT.history(1:(VAL.itctr - 1), 1:4); % Return history
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% AUXILIARY FUNCTION BLOCK
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
% Function  : SS
% Purpose   : Get options from inputs
%--------------------------------------------------------------------------
function SS = Options(opts, narg)
%--------------------------------------------------------------------------
% Determine option values
if nargin < 3 && (isempty(opts))
    opts = [];
end
getopts(opts, 'maxits', 1000, 'maxevals', 100000, 'maxdeep', 1000,...
    'testflag', 0, 'globalmin', 0, 'tol', 0.01, 'showits', 1);

SS.G_nargout = narg;     % output arguments
SS.MAXits    = maxits;   % maximum of iterations
SS.MAXevals  = maxevals; % maximum # of function evaluations
SS.MAXdeep   = maxdeep;  % maximum number of side divisions
SS.showITS   = showits;  % print iteration stat
SS.TOL       = tol;      % allowable relative error if f_reach is set
SS.TESTflag  = testflag; % terminate if within a relative tolerence of f_opt
SS.globalMIN = globalmin;% minimum value of function

workers = gcp();
SS.workers = workers.NumWorkers;
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : BEGIN
% Purpose   : Create necessary data accessible to all workers
%--------------------------------------------------------------------------
function [MV, MD, MSS, CE, third, VAL, SS] = Alocate(bounds, SS)
%--------------------------------------------------------------------------
% Create Initial values
tic                                     % Mesure time
VAL.a = bounds(:, 1);                   % left bound
VAL.b = bounds(:, 2);                   % right bound
VAL.n = size(bounds, 1);                % dimension
VAL.count = 1;
VAL.aloc = 10*VAL.n*SS.MAXdeep;
VAL.perror = 2*SS.TOL;                  % initial perror
CE = zeros(1, VAL.aloc);        % collum counter

% Create and allocating empty sets
[MV, MD] = deal(nan(3,VAL.aloc));     % for min values in collums
MSS = struct('F', zeros(1), 'E', zeros(1), 'C', zeros(VAL.n, 1),...
    'L', zeros(VAL.n, 1));

third           = zeros(1, VAL.aloc);     % delta values
third(1)        = 1/3;                      % first delta
for i = 2:VAL.aloc                        % all delta
    third(i)    = (1/3)*third(i - 1);
end
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : Initialization
% Purpose   : Create necessary data for master
%--------------------------------------------------------------------------
function [MV, MD, MSS, CE, DATA, VAL, SS, xmin, fmin] = Initialization(...
    Problem, MV, MD, MSS, CE, VAL, SS)
%--------------------------------------------------------------------------
% Create and allocating empty sets
SS.history = zeros(SS.MAXits, 4);              % allocating history
[MV(1:3,1), MD(1:3,1)] = deal(1);               % first fake value
[MSV, MSD] = deal(ones(4, 1));
VAL.fcount = 1;                                 % first fcnc counter
VAL.itctr = 1;                                  % initial iteration
VAL.time = 0;                                   % initial time
CE(1) = 1;                                      % \# in column.

% First evaluation
MSS(1).L(:, 1) = zeros(VAL.n,1);                % Lengths
MSS(1).C(:, 1) = ones(VAL.n,1)/2;               % Center point
MSS(1).E(1) = 1;                                % Index
point = abs(VAL.b-VAL.a).*MSS(1).C(:, 1) + VAL.a;
[MSS(1).F(1), fmin] = deal(feval(Problem.f, point));                      
[xmin, VAL.xatmin] = deal(MSS(1).C(:, 1));

% Divide values for workers
[KK, TT, I, DEL, VAL.fcount] = DIVas(1, 1, VAL, MSD, MSV, SS);
% work for master
DATA = {KK, TT, I, size(I,1), DEL, xmin};

%--------------------------------------------------------------------------
labSend(DATA, 2:SS.workers);               % Send jobs to workers
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : subdivision
% Purpose   : Calculate; new points, function values, lengths and indexes
%--------------------------------------------------------------------------
function [MSS, CE, MV, MD, DATA] = subdivision(VAL, Problem, DT, MSS,...
    CE, third, MV, MD)
%--------------------------------------------------------------------------
% Create sets
excess = find(~cellfun(@isempty, DT{2}));       % excess work on Workers
lack = find(cellfun(@isempty, DT{2}));          % lack work on Workers
MAIN.FF = [];                                   % create set MAIN

if ~isempty(excess)                            % Is any excess POH on Worker
    if ~isempty(DT{2}{labindex})
        % Create and allocating empty sets
        DO = size(DT{2}{labindex}, 2);
        [MM.F, MM.O, MM.E, MM.fef] = deal(zeros(1, DO));
        [MM.C, MM.L] = deal(zeros(VAL.n, DO));
        for j = 1:DO
            % Write information which be send
            MM.F(j) = MSS(DT{2}{labindex}(1, j)).F(DT{2}{labindex}(2, j));
            MM.E(j) = MSS(DT{2}{labindex}(1, j)).E(DT{2}{labindex}(2, j));
            MM.C(:, j) = MSS(DT{2}{labindex}(1, j)).C(:, DT{2}{labindex}(2, j));
            MM.L(:, j) = MSS(DT{2}{labindex}(1, j)).L(:, DT{2}{labindex}(2, j));
            MM.fef(j) = DT{2}{labindex}(3, j);
            MM.O(j) = DT{2}{labindex}(1, j);
        end
        labSend(MM, lack(1));       	 % Send information to other labs
    else
        % Receive information
        if labindex == lack(1)
            [MO.F, MO.O, MO.E, MO.fef, MO.L, MO.C] = deal([]);
            for j = 1:size(excess, 2)
                MOM = labReceive('any');
                MO.F = [MO.F, MOM.F];
                MO.O = [MO.O, MOM.O];
                MO.C = [MO.C, MOM.C];
                MO.L = [MO.L, MOM.L];
                MO.E = [MO.E, MOM.E];
                MO.fef = [MO.fef, MOM.fef];
            end
        else
            MO = labReceive('any');
        end
        jj = find(lack == labindex);
        xc = DT{3}(lack(jj)) - size(DT{1}{lack(jj)}, 2);
        MAIN.FF = MO.F(1:xc); MO.F = MO.F(xc + 1:end);
        MAIN.CC = MO.C(:, 1:xc); MO.C = MO.C(:, xc + 1:end);
        MAIN.EE = MO.E(1:xc);   MO.E = MO.E(xc + 1:end);
        MAIN.LL = MO.L(:, 1:xc); MO.L = MO.L(:, xc + 1:end);
        MAIN.OO = MO.O(1:xc);   MO.O = MO.O(xc + 1:end);
        MAIN.ISS = MO.fef(1:xc); MO.fef = MO.fef(xc + 1:end);
        if size(lack, 2) ~= jj
            labSend(MO, lack(jj + 1));
        end
    end
end

% STORAGE of new rectangles
[MSS, CE] = STORAGE(Problem, MSS, CE, third, VAL, DT, MAIN, MV, MD);

% Find minima values
[MV, MD, xmin, fmin] = find_min(CE, MSS, VAL.n, DT{6});
DATA = {MV, xmin, MD, fmin};
%--------------------------------------------------------------------------
labBarrier
if labindex ~= 1                        % Send info to master
    labSend(DATA, 1);
end
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : STORAGE
% Purpose   : Store information wrom workers
%--------------------------------------------------------------------------
function [MSS,CE] = STORAGE(Problem, MSS, CE, third, VAL, DATA, MAIN, MV, MD)
%--------------------------------------------------------------------------
[DD, LIMIT] = Calulcs(Problem, DATA, MSS, third, VAL, MAIN);

for i = 1:LIMIT
    for h = 1:DD{i}.S
        II = DD{i}.mdx + h;                          
        if CE(II) == 0
            [MSS(II).L, MSS(II).C] = deal(zeros(VAL.n, 100));
            [MSS(II).F, MSS(II).E] = deal(zeros(1, 100));
        end
        IL           = CE(II) + 1;              % Left index
        IR           = CE(II) + 2;              % Right index
        CE(II)       = IR;                      % Colum index
        if CE(II) > size(MSS(II).F,2)
            MSS(II).L = [MSS(II).L, zeros(VAL.n, 100)];
            MSS(II).F = [MSS(II).F, nan(1, 100)];
            MSS(II).E = [MSS(II).E, zeros(1, 100)];
            MSS(II).C = [MSS(II).C, zeros(VAL.n, 100)];
        end
        MSS(II).F(IL) = DD{i}.L(DD{i}.lsx(h));          % Left f(x)
        MSS(II).F(IR) = DD{i}.R(DD{i}.lsx(h));          % Right f(x)
        MSS(II).E(IL) = DD{i}.eL(h);                    % Left fcn counter
        MSS(II).E(IR) = DD{i}.eR(h);                    % Right fcn counter
        MSS(II).L(:, IL) = DD{i}.lL(:, h);              % Left lenght
        MSS(II).L(:, IR) = DD{i}.lL(:, h);              % Right lenght
        MSS(II).C(:, IL) = DD{i}.cL(:, DD{i}.lsx(h));   % Left x
        MSS(II).C(:, IR) = DD{i}.cR(:, DD{i}.lsx(h));   % Right x
    end
    II = DD{i}.mdx + DD{i}.S;                       % SET index
    CE(II) = CE(II) + 1;                            % Colum index
    MSS(II).F(CE(II)) = DD{i}.O;                    % Center f(x)
    MSS(II).E(CE(II)) = DD{i}.eO;                   % Center fcn counter
    MSS(II).C(:, CE(II)) = DD{i}.cO;                % Center x
    MSS(II).L(:, CE(II)) = DD{i}.lL(:, DD{i}.S);    % Center lenght
end

D_O = DATA{5}{labindex};                % Indexes which can be replaced
for i = 1:size(D_O{1}, 2)                                                      
    I = D_O{1}(i);                                                        
    if size(find(D_O{2} == I), 2) ~= 0 && MD(2, I) == CE(I)                          
        MD(2,I) = MV(2,I);
    end
    if CE(I) == 0
        [MSS(I).E, MSS(I).L, MSS(I).C, MSS(I).F] = deal([]);
    else
        MSS(I).E([MV(2, I), CE(I)]) = MSS(I).E([CE(I), MV(2, I)]);                  
        MSS(I).L(:, [MV(2, I), CE(I)]) = MSS(I).L(:, [CE(I), MV(2, I)]);                
        MSS(I).F([MV(2, I), CE(I)]) = MSS(I).F([CE(I), MV(2, I)]);                   
        MSS(I).C(:, [MV(2, I), CE(I)]) = MSS(I).C(:, [CE(I), MV(2, I)]);              
    end
    CE(I) = CE(I) - 1;                                                    
end
for i = 1:size(D_O{2}, 2)                                                  
    I = D_O{2}(i);                                                                                                         
    if CE(I) == 0
        [MSS(I).E, MSS(I).L, MSS(I).C, MSS(I).F] = deal([]);
    else
        MSS(I).E([MD(2, I), CE(I)]) = MSS(I).E([CE(I), MD(2, I)]);                   
        MSS(I).L(:, [MD(2, I), CE(I)]) = MSS(I).L(:, [CE(I), MD(2, I)]);                  
        MSS(I).F([MD(2, I), CE(I)]) = MSS(I).F([CE(I), MD(2, I)]);                    
        MSS(I).C(:, [MD(2, I), CE(I)]) = MSS(I).C(:, [CE(I), MD(2, I)]);                
    end
    CE(I) = CE(I) - 1;                                                   
end
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : Calulcs
% Purpose   : Calculate; new points, function values, lengths and indexes
%--------------------------------------------------------------------------
function [A, LIMIT] = Calulcs(PR, DATA, MSS, third, VAL, MAIN)
%--------------------------------------------------------------------------
LIMIT_w = size(DATA{1}{labindex},2);
LIMIT_s = size(MAIN.FF, 2);
LIMIT = LIMIT_s + LIMIT_w;
A = cell(1, LIMIT);
fc = zeros(1, LIMIT);
LL = zeros(VAL.n, LIMIT);

for i = 1:LIMIT_w
    A{i}.mdx = DATA{1}{labindex}(1, i);
    A{i}.O = MSS(A{i}.mdx).F(DATA{1}{labindex}(2, i));
    A{i}.eO = MSS(A{i}.mdx).E(DATA{1}{labindex}(2, i));
    A{i}.cO = MSS(A{i}.mdx).C(:, DATA{1}{labindex}(2, i));
    LL(:, i) = MSS(A{i}.mdx).L(:, DATA{1}{labindex}(2, i));
    fc(i) = DATA{1}{labindex}(3, i);
end

for i = 1:LIMIT_s
    j = LIMIT_w + i;
    A{j}.mdx = MAIN.OO(i);
    A{j}.O = MAIN.FF(i);
    A{j}.eO = MAIN.EE(i);
    A{j}.cO = MAIN.CC(:, i);
    LL(:, j) = MAIN.LL(:, i);
    fc(j) = MAIN.ISS(i);
end

for i = 1:LIMIT
    DIVIS = find(LL(:, i) == min(LL(:, i)));
    DELTA = third(min(LL(:, i)) + 1);
    A{i}.S = length(DIVIS);
    [A{i}.L, A{i}.R, A{i}.eL, A{i}.eR] = deal(zeros(1, A{i}.S));
    A{i}.lL = LL(:, i)*ones(1, A{i}.S);
    A{i}.cL = A{i}.cO*ones(1, A{i}.S); A{i}.cR = A{i}.cL;
    
    for g = 1:A{i}.S
        A{i}.cL(DIVIS(g), g) = A{i}.cL(DIVIS(g), g) - DELTA;
        A{i}.L(g) = feval(PR.f, abs(VAL.b - VAL.a).*A{i}.cL(:, g) + VAL.a);
        A{i}.cR(DIVIS(g), g) = A{i}.cR(DIVIS(g), g) + DELTA;
        A{i}.R(g) = feval(PR.f, abs(VAL.b - VAL.a).*A{i}.cR(:, g) + VAL.a);
    end
    [~, A{i}.lsx] = sort([min(A{i}.L, A{i}.R)' DIVIS], 1);
    for g = 1:A{i}.S
        A{i}.lL(DIVIS(A{i}.lsx(1:g, 1)), g) =...
                                   A{i}.lL(DIVIS(A{i}.lsx(1:g, 1)), g) + 1;
        A{i}.eL(g) = fc(i) + 1;
        A{i}.eR(g) = fc(i) + 2;
        fc(i) = fc(i) + 2;
    end
end
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : find_rectangles
% Purpose   : Return list of PO hyperrectangles
%--------------------------------------------------------------------------
function setas = find_rectangles(fc_min)
%--------------------------------------------------------------------------
% Create sets and define stop condition
  s_i   = 0;
  setas = zeros(1, size(fc_min, 2)); 
  index = size(fc_min, 2);
% Find index set of potential optimal hyper-rectangles
  while index ~= 0
   [m_m, index] = min(fc_min(1:index));
    if ~isnan(m_m)
      s_i = s_i + 1; 
      setas(s_i) = index;
    end
   index = index - 1;
  end
  setas  = setas(1:s_i);
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function   :  find_min
% Purpose    :  Find min value
%--------------------------------------------------------------------------
function [MV, MD, xmin, fmin] = find_min(CE, MSS, n, XX)
%--------------------------------------------------------------------------
if size(MSS, 2) ~= 1
    % Create sets
    [MV, MD, temp] = deal(nan(3, size(MSS, 2)));
    
    for i = 1:size(MSS, 2)                                  % DISTANCES
        if CE(i) ~= 0
            MSS(i).E = MSS(i).E(1:CE(i));
            D_eul = sum((XX - MSS(i).C(:, 1:CE(i))).^2).^0.5;
            TM = find(MSS(i).E(1:CE(i)) ==...
                                       max(MSS(i).E(D_eul == min(D_eul))));
            temp(1, i) = D_eul(TM);
            temp(2, i) = TM;
            temp(3, i) = MSS(i).E(TM);
        end
    end
    POH = flip(find_rectangles(temp(1, :)));
    MD(:, POH) = temp(:, POH);
    
    for i = 1:size(MSS,2)
        if CE(i) ~= 0
            TM = find(MSS(i).E(1:CE(i)) == max(MSS(i).E(MSS(i).F(1:CE(i))...
            == min(MSS(i).F(1:CE(i))))));
            temp(1, i) = MSS(i).F(TM);
            temp(2, i) = TM;
            temp(3, i) = MSS(i).E(TM);
        end
    end
    POH = flip(find_rectangles(temp(1, :)));
    MV(:, POH) = temp(:, POH);
    
    fmin(1) = min(MV(1, :));
    Least = find(MV(3, :) == max(MV(3, (MV(1, :) == fmin))));
    xmin = MSS(Least).C(:,MV(2, Least));
    fmin(2) = MV(3, Least);
else
    xmin = zeros(n, 1);
    fmin = nan(1, 2);
    [MV, MD] = deal(nan(3, 1));
end
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function   :  Split scalar
% Purpose    :  Divides rectangle i that is passed in
%--------------------------------------------------------------------------
function integerPerTask = split_scalar(intVal, numTasks)
%--------------------------------------------------------------------------
if intVal < numTasks
    numTasks = intVal;
end

split                         = fix(intVal / numTasks);
remainder                     = intVal - numTasks * split;
integerPerTask                = zeros(numTasks, 1);
integerPerTask(:)             = split;
integerPerTask(1:remainder)   = integerPerTask(1:remainder) + 1;
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : Master
% Purpose   : last calculs of master
%--------------------------------------------------------------------------
function [DATA, fmin, VAL, SS, xmin] = Master(VAL, SS, D, MSS)
%--------------------------------------------------------------------------
% Block any action until all workers reach this point
[count, LB, MN, ME]  = deal(ones(1, SS.workers));
[VR, IR, ER, DV, DI, DE] = deal(nan(SS.workers, VAL.count + VAL.n));
XR = zeros(VAL.n,SS.workers);
for i=1:SS.workers
    if i ~= labindex
        [D, L] = labReceive('any');     % Receive info from workers
        LB(i) = L;                      % labindex
    end
    count(i) = size(D{1}, 2);
    VR(i, 1:count(i)) = D{1}(1, :);     % Values
    IR(i, 1:count(i)) = D{1}(2, :);    	% indexes
    ER(i, 1:count(i)) = D{1}(3, :);     % fcount
    XR(:, i) = D{2}(:, 1);              % x
    MN(i) = D{4}(1);                    % minval
    ME(i) = D{4}(2);
    DV(i, 1:count(i)) = D{3}(1, :);
    DI(i, 1:count(i)) = D{3}(2, :);
    DE(i, 1:count(i)) = D{3}(3, :);
end
VAL.count = max(count);

[MSV, MSD] = deal(nan(4, VAL.count));
for i = 1:VAL.count                     % Find min values
    mm = min(DV(:, i));
    if ~isnan(mm)
        TM = find(DE(:, i) == max(DE(DV(:, i) == mm, i)));
        MSD(1, i) = DV(TM, i);
        MSD(2, i) = DI(TM, i);
        MSD(3, i) = LB(TM);
        MSD(4, i) = DE(TM, i);
    end
end

for i = 1:VAL.count                     % Find min values
    mm = min(VR(:, i));
    if ~isnan(mm)
        TM = find(ER(:, i) == max(ER(VR(:, i) == mm, i)));
        MSV(1, i) = VR(TM, i);
        MSV(2, i) = IR(TM, i);
        MSV(3, i) = LB(TM);
        MSV(4, i) = ER(TM, i);
    end
end

% Update f_min and x_min
fmin = min(MN);                         % f_min
fminindex = ME == max(ME(MN == fmin));
xmin = XR(:, fminindex);


POH_L = find_rectangles(MSD(1, :));
POH_G = find_rectangles(MSV(1, :));
[KK, TT, I, DEL, fcnc] = DIVas(POH_G, POH_L, VAL, MSD, MSV, SS);
DATA = {KK, TT, I, size(I, 1), DEL, xmin};

% Show iteration stats
if SS.showITS == 1
    VAL.time = toc;
    fprintf('Iter: %4i   f_min: %15.10f    time(s): %10.05f    fn evals: %8i\n',...
        VAL.itctr, fmin, VAL.time, VAL.fcount);
end
% Check for stop condition
if SS.TESTflag == 1
    % Calculate error if globalmin known
    if SS.globalMIN ~= 0
        
        VAL.perror = 100*(fmin - SS.globalMIN)/abs(SS.globalMIN);
    else
        VAL.perror = 100*fmin;
    end
    
    if VAL.perror < SS.TOL
        fprintf('Minima was found with Tolerance: %4i', SS.TOL);
        VAL.perror = -1;
    end
else
    VAL.perror = 10;
end
% Have we exceeded the maxits?
if VAL.itctr >= SS.MAXits
    disp('Exceeded max iterations. Increase maxits'); VAL.perror = -1;
end
% Have we exceeded the maxevals?
if VAL.fcount > SS.MAXevals
    disp('Exceeded max fcn evals. Increase maxevals'); VAL.perror = -1;
end
% Have we exceeded max deep?
if max(MSS(end).L(1)) > SS.MAXdeep
    disp('Exceeded Max depth. Increse maxdeep'); VAL.perror = -1;
end
if VAL.perror == -1
    labSend(DATA, 2:SS.workers,1);
else
    labSend(DATA, 2:SS.workers,2);
end
% Store History
if SS.G_nargout == 3
    SS.history(VAL.itctr,1) = VAL.itctr;
    SS.history(VAL.itctr,2) = VAL.fcount;
    SS.history(VAL.itctr,3) = fmin;
    SS.history(VAL.itctr,4) = VAL.time;
end

% Update iteration number
VAL.fcount = fcnc;
VAL.itctr = VAL.itctr + 1;
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% Function  : Decision
% Purpose   : Decide which workers whould delete theirs rectnagles
%--------------------------------------------------------------------------
function [KK, TT, I, HH, fnc] = DIVas(K, L, VAL, MSD, MSV, SS)
%--------------------------------------------------------------------------
L(ismember(MSV(4, L), intersect(MSV(4, K), MSD(4, L)))) = [];
Main = [K, L; MSV(2, K), MSD(2, L);...
                                VAL.fcount, zeros(1, size([K, L], 2) - 1)];                

I = flipud(split_scalar((size(Main, 2)), SS.workers));
[HH, KK, II, TT] = deal(cell(1, SS.workers));
I(size(I, 1) + 1:SS.workers) = 0;

for i = 2:size(Main, 2)
    [Main(3, i), VAL.fcount] = deal(VAL.fcount + (VAL.n -...
                                    mod(Main(1, i - 1) - 1, VAL.n))*2);
end
fnc = (VAL.fcount + (VAL.n - mod(Main(1, end) - 1, VAL.n))*2);

% Calculations
for i=1:SS.workers
    II{i} = find([MSV(3, K), MSD(3, L)] == i);
    HH{i}{1} = K(MSV(3, K) == i);
    HH{i}{2} = L(MSD(3, L) == i);
    if size(II{i}, 2) ~= 0
        if size(II{i}, 2) < (I(i)+1)
            KK{i} = Main(:, II{i});
        else
            TT{i} = Main(:, II{i}(I(i) + 1:size(II{i}, 2)));
            KK{i} = Main(:, II{i}(1:I(i)));
        end
    end
end
%--------------------------------------------------------------------------
return

%--------------------------------------------------------------------------
% GETOPTS Returns options values in an options structure
%--------------------------------------------------------------------------
function varargout = getopts(options, varargin)
K = fix(nargin/2);
if nargin/2 == K
    error('fields and default values must come in pairs')
end
if isa(options,'struct')
    optstruct = 1;
else
    optstruct = 0;
end
varargout = cell(K, 1);
k = 0; ii = 1;
for i = 1:K
    if optstruct && isfield(options, varargin{ii})
        assignin('caller', varargin{ii}, options.(varargin{ii}));
        k = k + 1;
    else
        assignin('caller', varargin{ii}, varargin{ii + 1});
    end
    ii = ii + 2;
end
if optstruct && k ~= size(fieldnames(options), 1)
    warning('options variable contains improper fields')
end
return
%--------------------------------------------------------------------------
% END of BLOCK
%--------------------------------------------------------------------------
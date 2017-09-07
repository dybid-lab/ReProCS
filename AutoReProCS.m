function [L_hat, P_hat, S_hat, T_hat, t_hat, ...
    P_track_full, P_track_new, T_calc]= AutoReProCS(M, ...
    P_init, ev_thresh, alpha, K, omega, outc, K_CS)
%%%This is the automatic version of ReProCS algorithm under the latest
%%%subspace change and support model. 

%This folder contains the code accompanying pre-print.
%
%[1] "New Results for Provable Dynamic Robust PCA", Praneeth Narayanamurthy and Namrata Vaswani, arXiv:1705.08948, 2017.
%
%If you use this code please also cite the following papers
%[2] "An online algorithm for separating sparse  and low-dimensional signal sequences from their sum", Han Guo, Chenlu Qiu, and Namrata Vaswani, IEEE Trans. Sig. Proc., 2014.
%[3] "Recursive Robust PCA or Recursive Sparse Recovery in Large but Structure Noise", Chenlu Qiu, Namrata Vaswani, Brain Lois, and Leslie Hogben, IEEE Trans. Info. Theory., 2014.
%[4] "Real-time Robust Principal Components' Pursuit", Chenlu Qiu, and Namrata Vaswani, Allerton, 2010.


%%%                          Inputs                         %%%
%%%     M - measurement matrix                              %%%
%%%     ev_thres - threshold for subspace change detection  %%%
%%%     P_init - an initial estimate of the subspace        %%%
%%%     t_train - the dimension of the training data        %%%


%%%                       Algorithm parameters              %%%
%%%     alpha - frame length                                %%%
%%%     K - number of projection PCA steps                  %%%
%%%     omega - threshold for non-zero value in S           %%%
%%% 	K_CS - number of CoSaMP iterations 		    %%%
%%% 	outc - an upper bound on estimate of fraction of outliers per column

%%%                          Outputs                        %%%
%%%     L_hat - estimate of the low rank matrix             %%%
%%%     P_hat - estimate of the subspace in which L lies    %%%
%%%     S_hat - estimate of the sparse signal               %%%
%%%     t_hat - estimate of subspace change times           %%%

%% Initializations
%thresh = ev_thresh / 2;
P_hat_old = P_init;
P_hat_new = [];
P_hat = [P_hat_old, P_hat_new];

[n, t_max] = size(M);
T_hat = zeros(n, t_max);
S_hat = zeros(n, t_max);
L_hat = zeros(n, t_max);
t_hat = [];

% L_hat(:, 1 : t_train) = M(:, 1 : t_train);
k = 0;
cnt = 1;
phi_t = (eye(n) - P_hat * P_hat');
% In = eye(n);
ph = 0;     %ph - 0 => detect, 1 => ppca

%% Main Algorithm Loop
for ii = 1 : t_max
    %% Estimate support
    y_t = M(:, ii) - (P_hat * (P_hat' * M(:, ii)));
    DecayRate = 0.9; %other values work, may make it slower
    x_t_hat_cs = cosamp_cgls(phi_t, ...
        y_t, outc, DecayRate, K_CS, 1e-6);
    t_hat_temp = find(abs(x_t_hat_cs) > omega);
    %     T_hat(t_hat_temp, ii) = 1;
    
    %% Estimate signal components
    % %         [S_hat(t_hat_temp, ii), ~] = ...
    % %             lsqr(phi_t(:, t_hat_temp), y_t, 1e-6, 50);
    %     S_hat(t_hat_temp, ii) = phi_t(:, t_hat_temp) \ y_t;
    S_hat(t_hat_temp, ii) = cgls(phi_t(:, t_hat_temp), y_t, ...
        0, 1e-10, 10);
    L_hat(:, ii) = M(:, ii) - S_hat(:, ii);
    
    
    %% Subspace update
    if(~mod(ii + 1 , alpha))
        u = (ii + 1) / alpha;
        idx = (u-1) * alpha + 1 : u * alpha ;
        L_temp = L_hat(:, idx);
        
        MM = L_temp - (P_hat_old *(P_hat_old' * L_temp));
        
        if(~ph)     %%detect phase
            %             phi_t = eye(n) - P_hat * P_hat';
            if(svds(MM, 1) >= sqrt(alpha * ev_thresh))
                ph = 1;
                t_hat = [t_hat, ii];
                k = 0;
            end
        else        %%ppca phase
            P_hat_new = proj_PCA_thresh(MM, sqrt(alpha * ev_thresh));
            P_hat = [P_hat_old, P_hat_new];
            phi_t = eye(n) - P_hat * P_hat';
            
            if(k == K)
                P_hat_old = P_hat;
                P_hat = P_hat_old;
            end
            
            k = k + 1;
            
            if(k == K + 1) %%deletion
                P_hat_old = proj_PCA(L_temp, [], rank(P_init));
                P_hat_new = [];
                P_hat = P_hat_old;
                k = 1;
                ph = 0;
                phi_t = eye(n) - P_hat * P_hat';
            end
        end
        
    end
    
    
    %% Return subspace
    if((ii == 1) || ~(mod(ii + 1, alpha)))
        P_track_full{cnt} = P_hat;
        P_track_new{cnt} = P_hat_new;
        T_calc(cnt) = ii;
        cnt = cnt + 1;
    end
end
end



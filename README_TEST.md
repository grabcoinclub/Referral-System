# Referral System

## ☑️ ReferralSystemBsc
### Main Prices in BNB
```
uint256[] public prices = [
    0,
    0.2 ether,
    0.3 ether,
    0.5 ether,
    1 ether,
    2 ether,
    3 ether,
    5 ether,
    10 ether,
    18 ether,
    30 ether,
    50 ether,
    100 ether,
    180 ether,
    300 ether,
    500 ether
];
```

### Test Prices in BNB
```
uint256[] public prices = [
    0,
    0.001 ether,
    0.002 ether,
    0.003 ether,
    0.004 ether,
    0.005 ether,
    0.006 ether,
    0.007 ether,
    0.008 ether,
    0.009 ether,
    0.010 ether,
    0.011 ether,
    0.012 ether,
    0.013 ether,
    0.014 ether,
    0.015 ether
];
```
#### Binary rates
```
uint256[] public binLevelRate = [
    0,
    600,
    600,
    700,
    700,
    700,
    800,
    800,
    900,
    900,
    1000,
    1000,
    1100,
    1100,
    1200,
    1200
];
```

### ☑️ Constructor params
- `refLevelRate` - 15 levels:
```
[
[0, 0, 0, 0, 0, 0, 0, 0],
[1000, 800, 100, 0, 0, 0, 0, 0],
[1000, 800, 200, 0, 0, 0, 0, 0],
[1000, 800, 300, 50, 0, 0, 0, 0],
[1000, 800, 400, 100, 0, 0, 0, 0],
[1000, 800, 500, 200, 0, 0, 0, 0],
[1000, 800, 600, 300, 50, 0, 0, 0],
[1000, 800, 600, 500, 100, 0, 0, 0],
[1000, 800, 600, 500, 200, 50, 0, 0],
[1000, 800, 600, 500, 300, 50, 0, 0],
[1000, 800, 600, 500, 400, 100, 50, 0],
[1000, 800, 600, 500, 400, 200, 50, 0],
[1000, 800, 600, 500, 400, 300, 100, 50],
[1000, 800, 600, 500, 400, 300, 100, 100],
[1000, 800, 600, 500, 400, 300, 100, 200],
[1000, 800, 600, 500, 400, 300, 100, 300]
]
```
☑️ or
```
[[0,0,0,0,0,0,0,0],[1000,800,100,0,0,0,0,0],[1000,800,200,0,0,0,0,0],[1000,800,300,50,0,0,0,0],[1000,800,400,100,0,0,0,0],[1000,800,500,200,0,0,0,0],[1000,800,600,300,50,0,0,0],[1000,800,600,500,100,0,0,0],[1000,800,600,500,200,50,0,0],[1000,800,600,500,300,50,0,0],[1000,800,600,500,400,100,50,0],[1000,800,600,500,400,200,50,0],[1000,800,600,500,400,300,100,50],[1000,800,600,500,400,300,100,100],[1000,800,600,500,400,300,100,200],[1000,800,600,500,400,300,100,300]]
```


## ☑️ ReferralSystemPolygon
### Main Prices in Matic
```
uint256[] public prices = [
    0,
    100 ether,
    300 ether,
    500 ether,
    700 ether,
    1_000 ether,
    3_000 ether,
    5_000 ether,
    7_000 ether,
    10_000 ether,
    30_000 ether,
    50_000 ether,
    70_000 ether,
    100_000 ether,
    150_000 ether,
    200_000 ether,
    300_000 ether
];
```

### Test Prices in Matic
```
uint256[] public prices = [
    0,
    0.001 ether,
    0.002 ether,
    0.003 ether,
    0.004 ether,
    0.005 ether,
    0.006 ether,
    0.007 ether,
    0.008 ether,
    0.009 ether,
    0.010 ether,
    0.011 ether,
    0.012 ether,
    0.013 ether,
    0.014 ether,
    0.015 ether,
    0.016 ether
];

```
### ☑️ Constructor params
- `refLevelRate` - 16 levels:
```
[
[0, 0, 0, 0, 0, 0, 0, 0],
[300, 0, 0, 0, 0, 0, 0, 0],
[300, 200, 0, 0, 0, 0, 0, 0],
[400, 200, 100, 0, 0, 0, 0, 0],
[400, 300, 200, 0, 0, 0, 0, 0],
[500, 400, 200, 0, 0, 0, 0, 0],
[500, 400, 300, 100, 0, 0, 0, 0],
[600, 500, 300, 100, 0, 0, 0, 0],
[600, 500, 400, 200, 0, 0, 0, 0],
[700, 500, 400, 300, 100, 0, 0, 0],
[700, 600, 500, 300, 200, 0, 0, 0],
[800, 600, 500, 400, 300, 100, 0, 0],
[800, 700, 600, 500, 300, 100, 0, 0],
[800, 700, 600, 500, 300, 200, 100, 0],
[900, 700, 600, 500, 400, 300, 100, 0],
[900, 800, 700, 500, 400, 300, 100, 0],
[1000, 800, 700, 500, 400, 300, 200, 100]
]
```
☑️ or
```
[[0,0,0,0,0,0,0,0],[300,0,0,0,0,0,0,0],[300,200,0,0,0,0,0,0],[400,200,100,0,0,0,0,0],[400,300,200,0,0,0,0,0],[500,400,200,0,0,0,0,0],[500,400,300,100,0,0,0,0],[600,500,300,100,0,0,0,0],[600,500,400,200,0,0,0,0],[700,500,400,300,100,0,0,0],[700,600,500,300,200,0,0,0],[800,600,500,400,300,100,0,0],[800,700,600,500,300,100,0,0],[800,700,600,500,300,200,100,0],[900,700,600,500,400,300,100,0],[900,800,700,500,400,300,100,0],[1000,800,700,500,400,300,200,100]]
```

#ifndef GLOBAL_MEMORY_H
#define GLOBAL_MEMORY_H

typedef enum {
    GLOBAL_ID = 0,
    GROUP_ID,
    GLOBAL_ID_X,
    GLOBAL_ID_Y,
    GLOBAL_ID_Z,
    TID_X,
    TID_Y,
    TID_Z,
    TID_W,
    NTID_X,
    NTID_Y,
    NTID_Z,
    NTID_W,
    CTAID_X,
    CTAID_Y,
    CTAID_Z,
    CTAID_W,
    NCTAID_X,
    NCTAID_Y,
    NCTAID_Z,
    NCTAID_W,
    WARP_SIZE,
    /* add register definitions here */
    MAX_REG_ID
}global_register_id;


#endif

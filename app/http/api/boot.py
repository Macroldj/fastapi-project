from fastapi import APIRouter

from fastapi.responses import JSONResponse

router = APIRouter(tags=['基础服务'])

@router.get('/ping',dependencies=[])
async def ping():
    return JSONResponse(content={'message': 'pong'}, status_code=200)
